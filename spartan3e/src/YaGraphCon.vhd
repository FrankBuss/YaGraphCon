-- Copyright (c) 2009 Frank Buss (fb@frank-buss.de)
-- See license.txt for license

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_bit.all;
use work.all;
use work.YaGraphConPackage.all;

entity YaGraphCon is
	generic(
		ADDRESS_WIDTH: natural;
		BIT_DEPTH: natural
	);
	port(
		-- main clock
		clock: in std_logic;
		
		-- microcontroller interface
		spiChipSelect: in std_logic;
		spiData: in std_logic;
		spiClock: in std_logic;
		busy: out std_logic;
		vsync: out std_logic;
		
		-- graphics output
	  	pixel: out unsigned(BIT_DEPTH-1 downto 0);
	  	vgaHsync: out std_logic;
	  	vgaVsync: out std_logic
	);
end entity YaGraphCon;

architecture rtl of YaGraphCon is
	constant PITCH_WIDTH: natural := min(16, ADDRESS_WIDTH);
	
	-- 1st RAM port for read-only access
	signal framebufferReadAddress1: unsigned(ADDRESS_WIDTH-1 downto 0);
	signal framebufferQ1: unsigned(BIT_DEPTH-1 downto 0);

	-- 2nd RAM port for read-only access
	signal framebufferReadAddress2: unsigned(ADDRESS_WIDTH-1 downto 0);
	signal framebufferQ2: unsigned(BIT_DEPTH-1 downto 0);

	-- 3rd RAM port for write access
	signal framebufferWriteAddress: unsigned(ADDRESS_WIDTH-1 downto 0);
	signal framebufferData: unsigned(BIT_DEPTH-1 downto 0);
	signal framebufferWriteEnable: std_logic;
	
	-- OutputGenerator signals
	signal framebufferStart: unsigned(ADDRESS_WIDTH-1 downto 0) := (others => '0');
	signal framebufferPitch: unsigned(PITCH_WIDTH-1 downto 0) := x"0280";
  
	-- GraphicsAccelerator signals
	signal reset: std_logic := '0';
	signal writeStart: unsigned(ADDRESS_WIDTH-1 downto 0);
	signal writeSize: unsigned(ADDRESS_WIDTH-1 downto 0);
	signal srcStart: unsigned(ADDRESS_WIDTH-1 downto 0);
	signal srcPitch: unsigned(PITCH_WIDTH-1 downto 0);
	signal dstStart: unsigned(ADDRESS_WIDTH-1 downto 0);
	signal dstPitch: unsigned(PITCH_WIDTH-1 downto 0);
	signal color: unsigned(BIT_DEPTH-1 downto 0);
	signal lineX0: unsigned(15 downto 0);
	signal lineY0: unsigned(15 downto 0);
	signal blitWidth: unsigned(15 downto 0);
	signal blitHeight: unsigned(15 downto 0);
	signal blitTransparent: std_logic;
	signal srcX0: unsigned(15 downto 0);
	signal srcY0: unsigned(15 downto 0);
	signal srcX1: unsigned(15 downto 0);
	signal dstX0: unsigned(15 downto 0);
	signal dstY0: unsigned(15 downto 0);
	signal dstX1: unsigned(15 downto 0);
	signal dstY1: unsigned(15 downto 0);
	signal command: unsigned(7 downto 0);
	signal start: std_logic;
	signal acceleratorBusy: std_logic;
	signal acceleratorWriteAddress: unsigned(ADDRESS_WIDTH-1 downto 0);
	signal acceleratorData: unsigned(BIT_DEPTH-1 downto 0);
	signal acceleratorWriteEnable: std_logic;
	
	-- SPI signals
	signal spiChipSelectLatch: std_logic;
	signal spiChipSelectVector: std_logic_vector(1 downto 0);
	signal spiDataLatch: std_logic;
	signal spiClockLatch: std_logic;
	signal spiClockVector: std_logic_vector(1 downto 0);
	signal receivedWord: unsigned(max(ADDRESS_WIDTH-1, 15) downto 0);
	signal receivedBitsCount: natural range 0 to 24 := 0;

	-- statemachine
	type commandParserStateType is (
		WAIT_FOR_COMMAND,
		WAIT_FRAMEBUFFER_START_ADDRESS,
		WAIT_FRAMEBUFFER_PITCH_OFFSET,
		WAIT_DESTINATION_START_ADDRESS,
		WAIT_DESTINATION_PITCH_OFFSET,
		WAIT_SOURCE_START_ADDRESS,
		WAIT_SOURCE_PITCH_ADDRESS,
		WAIT_COLOR,
		WAIT_SET_PIXEL_X,
		WAIT_SET_PIXEL_Y,
		WAIT_MOVE_TO_X,
		WAIT_MOVE_TO_Y,
		WAIT_LINE_TO_X,
		WAIT_LINE_TO_Y,
		WAIT_FILL_RECT_X0,
		WAIT_FILL_RECT_Y0,
		WAIT_FILL_RECT_WIDTH,
		WAIT_FILL_RECT_HEIGHT,
		WAIT_BLIT_SIZE_WIDTH,
		WAIT_BLIT_SIZE_HEIGHT,
		WAIT_BLIT_SOURCE_X,
		WAIT_BLIT_SOURCE_Y,
		WAIT_BLIT_DESTINATION_X,
		WAIT_BLIT_DESTINATION_Y,
		WAIT_WRITE_FRAMEBUFFER_ADDRESS,
		WAIT_WRITE_FRAMEBUFFER_SIZE,
		WAIT_WRITE_FRAMEBUFFER_BITS,
		WAIT_FOR_COMMAND_END
	);
	signal commandParserState: commandParserStateType := WAIT_FOR_COMMAND;

begin

	Framebuffer_instance: entity Framebuffer
		generic map(ADDRESS_WIDTH, BIT_DEPTH)
		port map(
			clock => clock,
			readAddress1 => framebufferReadAddress1,
			q1 => framebufferQ1,
			readAddress2 => framebufferReadAddress2,
			q2 => framebufferQ2,
			writeAddress => framebufferWriteAddress,
			data => framebufferData,
			writeEnable => framebufferWriteEnable
		);

	OutputGenerator_instance: entity OutputGenerator
		generic map(ADDRESS_WIDTH, BIT_DEPTH, PITCH_WIDTH)
		port map(
			clock => clock,
			pixel => pixel,
			vgaHsync => vgaHsync,
			vgaVsync => vgaVsync,
			vsync => vsync,
			readAddress => framebufferReadAddress1,
			q => framebufferQ1,
			framebufferStart => framebufferStart,
			framebufferPitch => framebufferPitch
		);

	GraphicsAccelerator_instance: entity GraphicsAccelerator
		generic map(ADDRESS_WIDTH, BIT_DEPTH, PITCH_WIDTH)
		port map(
			clock => clock,
			reset => reset,
			srcStart => srcStart,
			srcPitch => srcPitch,
			dstStart => dstStart,
			dstPitch => dstPitch,
			color => color,
			srcX0 => srcX0,
			srcY0 => srcY0,
			srcX1 => srcX1,
			dstX0 => dstX0,
			dstY0 => dstY0,
			dstX1 => dstX1,
			dstY1 => dstY1,
			blitTransparent => blitTransparent,
			command => command,
			start => start,
			busy => acceleratorBusy,
			readAddress => framebufferReadAddress2,
			writeAddress => acceleratorWriteAddress,
			data => acceleratorData,
			q => framebufferQ2,
			writeEnable => acceleratorWriteEnable
		);

	process(clock)
	begin
		if rising_edge(clock) then
			reset <= '0';
			start <= '0';
			framebufferWriteAddress <= acceleratorWriteAddress;
			framebufferData <= acceleratorData;
			framebufferWriteEnable <= acceleratorWriteEnable;
			spiChipSelectLatch <= spiChipSelect;
			spiChipSelectVector <= spiChipSelectVector(0) & spiChipSelectLatch;
			spiDataLatch <= spiData;
			spiClockLatch <= spiClock;
			spiClockVector <= spiClockVector(0) & spiClockLatch;
			if spiChipSelectLatch = '0' then
				if spiClockVector = "01" then
					receivedWord <= receivedWord(receivedWord'high-1 downto 0) & spiDataLatch;
					receivedBitsCount <= receivedBitsCount + 1;
				end if;
				busy <= acceleratorBusy;
			end if;
			if spiChipSelectVector = "01" then
				receivedBitsCount <= 0;
				commandParserState <= WAIT_FOR_COMMAND;
				busy <= '1';
			end if;
			case commandParserState is
				when WAIT_FOR_COMMAND =>
					if receivedBitsCount = 8 then
						command <= receivedWord(7 downto 0);
						case receivedWord(7 downto 0) is
							when RESET_COMMAND =>
								reset <= '1';
								srcStart <= (others => '0');
								srcPitch <= (others => '0');
								dstStart <= (others => '0');
								dstPitch <= (others => '0');
								color <= (others => '0');
								srcX0 <= (others => '0');
								srcY0 <= (others => '0');
								srcX1 <= (others => '0');
								dstX0 <= (others => '0');
								dstY0 <= (others => '0');
								dstX1 <= (others => '0');
								dstY1 <= (others => '0');
								blitTransparent <= '0';
								commandParserState <= WAIT_FOR_COMMAND_END;
							when SET_FRAMEBUFFER_START =>
								commandParserState <= WAIT_FRAMEBUFFER_START_ADDRESS;
							when SET_FRAMEBUFFER_PITCH =>
								commandParserState <= WAIT_FRAMEBUFFER_PITCH_OFFSET;
							when SET_DESTINATION_START =>
								commandParserState <= WAIT_DESTINATION_START_ADDRESS;
							when SET_DESTINATION_PITCH =>
								commandParserState <= WAIT_DESTINATION_PITCH_OFFSET;
							when SET_SOURCE_START =>
								commandParserState <= WAIT_SOURCE_START_ADDRESS;
							when SET_SOURCE_PITCH =>
								commandParserState <= WAIT_SOURCE_PITCH_ADDRESS;
							when SET_COLOR =>
								commandParserState <= WAIT_COLOR;
							when SET_PIXEL =>
								commandParserState <= WAIT_SET_PIXEL_X;
							when MOVE_TO =>
								commandParserState <= WAIT_MOVE_TO_X;
							when LINE_TO =>
								commandParserState <= WAIT_LINE_TO_X;
							when FILL_RECT =>
								commandParserState <= WAIT_FILL_RECT_X0;
							when BLIT_SIZE =>
								commandParserState <= WAIT_BLIT_SIZE_WIDTH;
							when BLIT_COMMAND =>
								blitTransparent <= '0';
								commandParserState <= WAIT_BLIT_SOURCE_X;
							when BLIT_TRANSPARENT =>
								blitTransparent <= '1';
								commandParserState <= WAIT_BLIT_SOURCE_X;
							when WRITE_FRAMEBUFFER =>
								commandParserState <= WAIT_WRITE_FRAMEBUFFER_ADDRESS;
							when others =>
						end case;
						receivedBitsCount <= 0;
					end if;
				when WAIT_FRAMEBUFFER_START_ADDRESS =>
					if receivedBitsCount = 24 then
						framebufferStart <= receivedWord(ADDRESS_WIDTH-1 downto 0);
						commandParserState <= WAIT_FOR_COMMAND_END;
					end if;
				when WAIT_FRAMEBUFFER_PITCH_OFFSET =>
					if receivedBitsCount = 16 then
						framebufferPitch <= receivedWord(PITCH_WIDTH-1 downto 0);
						commandParserState <= WAIT_FOR_COMMAND_END;
					end if;
				when WAIT_DESTINATION_START_ADDRESS =>
					if receivedBitsCount = 24 then
						dstStart <= receivedWord(ADDRESS_WIDTH-1 downto 0);
						commandParserState <= WAIT_FOR_COMMAND_END;
					end if;
				when WAIT_DESTINATION_PITCH_OFFSET =>
					if receivedBitsCount = 16 then
						dstPitch <= receivedWord(PITCH_WIDTH-1 downto 0);
						commandParserState <= WAIT_FOR_COMMAND_END;
					end if;
				when WAIT_SOURCE_START_ADDRESS =>
					if receivedBitsCount = 24 then
						srcStart <= receivedWord(ADDRESS_WIDTH-1 downto 0);
						commandParserState <= WAIT_FOR_COMMAND_END;
					end if;
				when WAIT_SOURCE_PITCH_ADDRESS =>
					if receivedBitsCount = 16 then
						srcPitch <= receivedWord(PITCH_WIDTH-1 downto 0);
						commandParserState <= WAIT_FOR_COMMAND_END;
					end if;
				when WAIT_COLOR =>
					if receivedBitsCount = BIT_DEPTH then
						color <= receivedWord(BIT_DEPTH-1 downto 0);
						commandParserState <= WAIT_FOR_COMMAND_END;
					end if;
				when WAIT_SET_PIXEL_X =>
					if receivedBitsCount = 16 then
						dstX0 <= receivedWord(15 downto 0);
						receivedBitsCount <= 0;
						commandParserState <= WAIT_SET_PIXEL_Y;
					end if;
				when WAIT_SET_PIXEL_Y =>
					if receivedBitsCount = 16 then
						dstY0 <= receivedWord(15 downto 0);
						start <= '1';
						commandParserState <= WAIT_FOR_COMMAND_END;
					end if;
				when WAIT_MOVE_TO_X =>
					if receivedBitsCount = 16 then
						lineX0 <= receivedWord(15 downto 0);
						receivedBitsCount <= 0;
						commandParserState <= WAIT_MOVE_TO_Y;
					end if;
				when WAIT_MOVE_TO_Y =>
					if receivedBitsCount = 16 then
						lineY0 <= receivedWord(15 downto 0);
						receivedBitsCount <= 0;
						commandParserState <= WAIT_FOR_COMMAND_END;
					end if;
				when WAIT_LINE_TO_X =>
					if receivedBitsCount = 16 then
						dstX0 <= receivedWord(15 downto 0);
						receivedBitsCount <= 0;
						commandParserState <= WAIT_LINE_TO_Y;
					end if;
				when WAIT_LINE_TO_Y =>
					if receivedBitsCount = 16 then
						dstY0 <= receivedWord(15 downto 0);
						dstX1 <= lineX0;
						dstY1 <= lineY0;
						lineX0 <= dstX0;
						lineY0 <= receivedWord(15 downto 0);
						start <= '1';
						commandParserState <= WAIT_FOR_COMMAND_END;
					end if;
				when WAIT_FILL_RECT_X0 =>
					if receivedBitsCount = 16 then
						dstX0 <= receivedWord(15 downto 0);
						receivedBitsCount <= 0;
						commandParserState <= WAIT_FILL_RECT_Y0;
					end if;
				when WAIT_FILL_RECT_Y0 =>
					if receivedBitsCount = 16 then
						dstY0 <= receivedWord(15 downto 0);
						receivedBitsCount <= 0;
						commandParserState <= WAIT_FILL_RECT_WIDTH;
					end if;
				when WAIT_FILL_RECT_WIDTH =>
					if receivedBitsCount = 16 then
						if receivedWord(15 downto 0) = 0 then
							commandParserState <= WAIT_FOR_COMMAND_END;
						else
							dstX1 <= receivedWord(15 downto 0) + dstX0 - 1;
							receivedBitsCount <= 0;
							commandParserState <= WAIT_FILL_RECT_HEIGHT;
						end if;
					end if;
				when WAIT_FILL_RECT_HEIGHT =>
					if receivedBitsCount = 16 then
						if receivedWord(15 downto 0) = 0 then
							commandParserState <= WAIT_FOR_COMMAND_END;
						else
							dstY1 <= receivedWord(15 downto 0) + dstY0 - 1;
							start <= '1';
							commandParserState <= WAIT_FOR_COMMAND_END;
						end if;
					end if;
				when WAIT_BLIT_SIZE_WIDTH =>
					if receivedBitsCount = 16 then
						blitWidth <= receivedWord(15 downto 0);
						receivedBitsCount <= 0;
						commandParserState <= WAIT_BLIT_SIZE_HEIGHT;
					end if;
				when WAIT_BLIT_SIZE_HEIGHT =>
					if receivedBitsCount = 16 then
						blitHeight <= receivedWord(15 downto 0);
						commandParserState <= WAIT_FOR_COMMAND_END;
					end if;
				when WAIT_BLIT_SOURCE_X =>
					if receivedBitsCount = 16 then
						srcX0 <= receivedWord(15 downto 0);
						receivedBitsCount <= 0;
						commandParserState <= WAIT_BLIT_SOURCE_Y;
					end if;
				when WAIT_BLIT_SOURCE_Y =>
					if receivedBitsCount = 16 then
						srcY0 <= receivedWord(15 downto 0);
						receivedBitsCount <= 0;
						commandParserState <= WAIT_BLIT_DESTINATION_X;
					end if;
				when WAIT_BLIT_DESTINATION_X =>
					if receivedBitsCount = 16 then
						dstX0 <= receivedWord(15 downto 0);
						receivedBitsCount <= 0;
						commandParserState <= WAIT_BLIT_DESTINATION_Y;
					end if;
				when WAIT_BLIT_DESTINATION_Y =>
					if receivedBitsCount = 16 then
						if blitWidth = 0 or blitHeight = 0 then
							commandParserState <= WAIT_FOR_COMMAND_END;
						else
							dstY0 <= receivedWord(15 downto 0);
							srcX1 <= srcX0 + blitWidth - 1;
							dstX1 <= dstX0 + blitWidth - 1;
							dstY1 <= receivedWord(15 downto 0) + blitHeight - 1;
							start <= '1';
							commandParserState <= WAIT_FOR_COMMAND_END;
						end if;
					end if;
				when WAIT_WRITE_FRAMEBUFFER_ADDRESS =>
					if receivedBitsCount = 24 then
						writeStart <= receivedWord(ADDRESS_WIDTH-1 downto 0);
						receivedBitsCount <= 0;
						commandParserState <= WAIT_WRITE_FRAMEBUFFER_SIZE;
					end if;
				when WAIT_WRITE_FRAMEBUFFER_SIZE =>
					if receivedBitsCount = 24 then
						writeSize <= receivedWord(ADDRESS_WIDTH-1 downto 0);
						receivedBitsCount <= 0;
						commandParserState <= WAIT_WRITE_FRAMEBUFFER_BITS;
					end if;
				when WAIT_WRITE_FRAMEBUFFER_BITS =>
					if receivedBitsCount = BIT_DEPTH then
						if writeSize > 0 then
							framebufferWriteAddress <= writeStart;
							framebufferData <= receivedWord(BIT_DEPTH - 1 downto 0);
							framebufferWriteEnable <= '1';
							writeStart <= writeStart + 1;
							writeSize <= writeSize - 1;
						else
							commandParserState <= WAIT_FOR_COMMAND_END;
						end if;
						receivedBitsCount <= 0;
					end if;
				when WAIT_FOR_COMMAND_END => null;
				when others =>
					commandParserState <= WAIT_FOR_COMMAND;
			end case;
		end if;
	end process;

end architecture rtl;

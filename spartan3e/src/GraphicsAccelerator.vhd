-- Copyright (c) 2009 Frank Buss (fb@frank-buss.de)
-- See license.txt for license

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.all;
use work.YaGraphConPackage.all;

entity GraphicsAccelerator is
	generic(
		ADDRESS_WIDTH: natural;
		BIT_DEPTH: natural;
		PITCH_WIDTH: natural
	);
	port(
		clock: in std_logic;
		reset:in std_logic;
		
		-- register interface
		srcStart: in unsigned(ADDRESS_WIDTH-1 downto 0);
		srcPitch: in unsigned(PITCH_WIDTH-1 downto 0);
		dstStart: in unsigned(ADDRESS_WIDTH-1 downto 0);
		dstPitch: in unsigned(PITCH_WIDTH-1 downto 0);
		color: in unsigned(BIT_DEPTH-1 downto 0);
		srcX0: in unsigned(15 downto 0);
		srcY0: in unsigned(15 downto 0);
		srcX1: in unsigned(15 downto 0);
		dstX0: in unsigned(15 downto 0);
		dstY0: in unsigned(15 downto 0);
		dstX1: in unsigned(15 downto 0);
		dstY1: in unsigned(15 downto 0);
		blitTransparent: in std_logic;
		command: in unsigned(7 downto 0);
		
		-- operation interface
		start: in std_logic;
		busy: out std_logic;

		-- framebuffer interface
		readAddress: out unsigned(ADDRESS_WIDTH-1 downto 0);
		writeAddress: out unsigned(ADDRESS_WIDTH-1 downto 0);
		data: out unsigned(BIT_DEPTH-1 downto 0);
		q: in unsigned(BIT_DEPTH-1 downto 0);
		writeEnable: out std_logic
	);
end entity GraphicsAccelerator;

architecture rtl of GraphicsAccelerator is

	-- statemachine
	type stateType is (
		WAIT_FOR_START,
		PIXEL,
		LINE_INIT,
		HORIZONTAL_LINE,
		VERTICAL_LINE,
		RECT,
		BLIT_DELAY1,
		BLIT_DELAY2,
		BLIT
	);
	signal state: stateType := WAIT_FOR_START;

	signal x: unsigned(15 downto 0);
	signal y: unsigned(15 downto 0);
	signal x2: unsigned(15 downto 0);
	signal y2: unsigned(15 downto 0);
	signal dx: unsigned(15 downto 0);
	signal dy: unsigned(15 downto 0);
	signal incx: std_logic;
	signal incy: std_logic;
	signal balance: signed(15 downto 0);

begin

	process(clock)
		variable dx2: unsigned(dx'high downto 0);
		variable dy2: unsigned(dy'high downto 0);
		procedure setPixel(x: unsigned(15 downto 0); y: unsigned(15 downto 0); clr: unsigned(BIT_DEPTH-1 downto 0)) is
		begin
			writeAddress <= adjustLength(dstStart + dstPitch * y + x, writeAddress'length);
			writeEnable <= '1';
			data <= clr;
		end;
		procedure nextBlitRead is
		begin
			readAddress <= adjustLength(srcStart + srcPitch * y2 + x2, readAddress'length);
			if x2 < srcX1 then
				x2 <= x2 + 1;
			else
				x2 <= srcX0;
				y2 <= y2 + 1;
			end if;
		end;
		procedure doIncx is
		begin
			if incx = '1' then
				x <= x + 1;
			else
				x <= x - 1;
			end if;
		end;
		procedure doIncy is
		begin
			if incy = '1' then
				y <= y + 1;
			else
				y <= y - 1;
			end if;
		end;
	begin
		if rising_edge(clock) then
			if reset = '1' then
				state <= WAIT_FOR_START;
				busy <= '0';
			else
				writeEnable <= '0';
				case state is
					when WAIT_FOR_START =>
						busy <= '0';
						if start = '1' then
							busy <= '1';
							case command is
								when SET_PIXEL =>
									x <= dstX0;
									y <= dstY0;
									state <= PIXEL;
								when LINE_TO =>
									if dstX1 >= dstX0 then
										dx <= dstX1 - dstX0;
										incx <= '1';
									else
										dx <= dstX0 - dstX1;
										incx <= '0';
									end if;
									if dstY1 >= dstY0 then
										dy <= dstY1 - dstY0;
										incy <= '1';
									else
										dy <= dstY0 - dstY1;
										incy <= '0';
									end if;
									x <= dstX0;
									y <= dstY0;
									x2 <= dstX1;
									y2 <= dstY1;
									state <= LINE_INIT;
								when FILL_RECT =>
									x <= dstX0;
									y <= dstY0;
									state <= RECT;
								when BLIT_COMMAND | BLIT_TRANSPARENT =>
									x <= dstX0;
									y <= dstY0;
									x2 <= srcX0;
									y2 <= srcY0;
									state <= BLIT_DELAY1;
								when others => null;
							end case;
						end if;
					when PIXEL =>
						setPixel(x, y, color);
						state <= WAIT_FOR_START;
					when LINE_INIT =>
						dx2 := dx(dx'high - 1 downto 0) & "0";
						dy2 := dy(dy'high - 1 downto 0) & "0";
						if dx >= dy then
							balance <= to_signed(to_integer(dy2) - to_integer(dx), balance'length);
							state <= HORIZONTAL_LINE;
						else
							balance <= to_signed(to_integer(dx2) - to_integer(dy), balance'length);
							state <= VERTICAL_LINE;
						end if;
						dx <= dx2;
						dy <= dy2;
					when HORIZONTAL_LINE =>
						if x /= x2 then
							setPixel(x, y, color);
							if balance >= 0 then
								doIncy;
								balance <= balance - to_integer(dx) + to_integer(dy);
							else
								balance <= balance + to_integer(dy);
							end if;
							doIncx;
						else
							setPixel(x, y, color);
							state <= WAIT_FOR_START;
						end if;
					when VERTICAL_LINE =>
						if y /= y2 then
							setPixel(x, y, color);
							if balance >= 0 then
								doIncx;
								balance <= balance - to_integer(dy) + to_integer(dx);
							else
								balance <= balance + to_integer(dx);
							end if;
							doIncy;
						else
							setPixel(x, y, color);
							state <= WAIT_FOR_START;
						end if;
					when RECT =>
						setPixel(x, y, color);
						if x < dstX1 then
							x <= x + 1;
						else
							x <= dstX0;
							if y < dstY1 then
								y <= y + 1;
							else
								state <= WAIT_FOR_START;
							end if;
						end if;
					when BLIT_DELAY1 =>
						nextBlitRead;
						state <= BLIT_DELAY2;
					when BLIT_DELAY2 =>
						nextBlitRead;
						state <= BLIT;
					when BLIT =>
						if blitTransparent = '1' then
							if q /= color then
								setPixel(x, y, q);
							end if;
						else
							setPixel(x, y, q);
						end if;
						if x < dstX1 then
							x <= x + 1;
						else
							x <= dstX0;
							if y < dstY1 then
								y <= y + 1;
							else
								state <= WAIT_FOR_START;
							end if;
						end if;
						nextBlitRead;
					when others =>
						state <= WAIT_FOR_START;
				end case;
			end if;
		end if;
	end process;

end architecture rtl;

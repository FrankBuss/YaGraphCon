-- Copyright (c) 2009 Frank Buss (fb@frank-buss.de)
-- See license.txt for license

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.all;

entity test is
	port(
		clk_50mhz: in std_logic;
		rs232_dce_txd: out std_logic;
		rs232_dce_rxd: in std_logic;
		led: out unsigned(7 downto 0);
		VGA_BLUE: out std_logic;
		VGA_GREEN: out std_logic;
		VGA_HSYNC: out std_logic;
		VGA_RED: out std_logic;
		VGA_VSYNC: out std_logic
	);
end entity test;

architecture rtl of test is
	constant ADDRESS_WIDTH: natural := 17;
	constant BIT_DEPTH: natural := 1;

	constant SYSTEM_SPEED: natural := 50e6;
	constant BAUDRATE: natural := 115200;

	signal rs232DataReceived: std_logic := '0';
	signal rs232DataIn: unsigned(7 downto 0) := (others => '0');

	signal rs232SendTrigger: std_logic := '0';
	signal rs232DataOut: unsigned(7 downto 0);

	signal ledLatch: unsigned(7 downto 0) := (others => '0');
	signal counter: natural range 0 to (system_speed / 2) := 0;

	signal spiChipSelect: std_logic;
	signal spiData: std_logic;
	signal spiClock: std_logic;

	signal busy: std_logic;
	signal busyVector: unsigned(1 downto 0);
	signal vsync: std_logic;
	signal pixel: unsigned(BIT_DEPTH-1 downto 0);
	signal vgaHsync: std_logic;
	signal vgaVsync: std_logic;
  
begin

	YaGraphCon_instance: entity YaGraphCon
		generic map(ADDRESS_WIDTH, BIT_DEPTH)
		port map(
			clock => clk_50mhz,
			spiChipSelect => spiChipSelect,
			spiData => spiData,
			spiClock => spiClock,
			busy => busy,
			vsync => vsync,
			pixel => pixel,
			vgaHsync => vgaHsync,
			vgaVsync => vgaVsync
		);

	sender: entity rs232_sender
		generic map(SYSTEM_SPEED, BAUDRATE)
		port map(
			clock => clk_50mhz,
			data => rs232DataOut,
			tx => rs232_dce_txd,
			sendTrigger => rs232SendTrigger,
			dataSent => ledLatch(4)
		);

	receiver: entity rs232_receiver
		generic map(SYSTEM_SPEED, BAUDRATE)
		port map(
			clock => clk_50mhz,
			reset => '0',
			data => rs232DataIn,
			rx => rs232_dce_rxd,
			dataReceived => rs232DataReceived
		);

	process(clk_50mhz)
	begin
		if rising_edge(clk_50mhz) then
			rs232SendTrigger <= '0';
			if rs232DataReceived = '1' then
				case rs232DataIn is
					-- "t" for testing: invert LED
					when x"74" =>
						ledLatch(3) <= not ledLatch(3);
						
					-- other commands for the SPI signals
					when x"00" =>
						spiChipSelect <= '1';
					when x"01" =>
						spiChipSelect <= '0';
					when x"02" =>
						spiClock <= '1';
					when x"03" =>
						spiClock <= '0';
					when x"04" =>
						spiData <= '1';
					when x"05" =>
						spiData <= '0';
					
					-- other bytes: echo, for RS232 TX/RX test
					when others =>
						rs232DataOut <= rs232DataIn;
						rs232SendTrigger <= '1';
				end case;
			end if;
			
			-- signal falling busy signal with "o" for "ok"
			busyVector <= busyVector(0) & busy;
			if busyVector = "10" then
				rs232DataOut <= x"6f";
				rs232SendTrigger <= '1';
			end if;

			-- 1 Hz LED blinker
			if counter = 0 then
				ledLatch(0) <= not ledLatch(0);
				counter <= SYSTEM_SPEED / 2;
			else
				counter <= counter - 1;
			end if;

			-- routing some internal signals to the LEDs
			ledLatch(1) <= busy;
			ledLatch(2) <= vsync;
			ledLatch(3) <= rs232_dce_rxd;
			ledLatch(5) <= pixel(0);
			ledLatch(6) <= vgaHsync;
			ledLatch(7) <= vgaVsync;
		end if;
	end process;

	led <= ledLatch;

	VGA_RED <= pixel(0);
	VGA_GREEN <= pixel(0);
	VGA_BLUE <= pixel(0);
	VGA_HSYNC <= vgaHsync;
	VGA_VSYNC <= vgaVsync;
  
end architecture rtl;

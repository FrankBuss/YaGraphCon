-- Copyright (c) 2009 Frank Buss (fb@frank-buss.de)
-- See license.txt for license
--
-- Simple RS232 sender with generic baudrate and 8N1 mode.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
USE work.all;

entity rs232_sender is
	generic(
		-- clock frequency, in hz
		SYSTEM_SPEED,
		
		-- baudrate, in bps
		BAUDRATE: integer
	);  
	port(
		clock: in std_logic;
		
		-- RS232 for sending
		data: in unsigned(7 downto 0);
		
		-- RS232 TX pin
		tx: out std_logic;
		
		-- set this for one clock pulse to 1 for sending the data
		sendTrigger: in std_logic;
		
		-- this is set for one clock pulse to 1, when the data was sent
		dataSent: out std_logic
	);
end entity rs232_sender;

architecture rtl of rs232_sender is
	constant MAX_COUNTER: natural := SYSTEM_SPEED / BAUDRATE;
	signal baudrateCounter: natural range 0 to MAX_COUNTER := 0;
	signal bitCounter: natural range 0 to 9 := 0;
	signal shiftRegister: unsigned(9 downto 0) := (others => '0');
	signal dataSendingStarted: std_logic := '0';

begin

	process(clock)
	begin
		if rising_edge(clock) then
			dataSent <= '0';
			if dataSendingStarted = '1' then
				if baudrateCounter = 0 then
					tx <= shiftRegister(0);
					shiftRegister <= shift_right(shiftRegister, 1);
					if bitCounter > 0 then
						bitCounter <= bitCounter - 1;
					else
						dataSendingStarted <= '0';
						dataSent <= '1';
					end if;
					baudrateCounter <= MAX_COUNTER;
				else
					baudrateCounter <= baudrateCounter - 1;
				end if;
			else
				tx <= '1';
				if sendTrigger = '1' then
					shiftRegister <= '1' & data & '0';
					bitCounter <= 9;
					baudrateCounter <= 0;
					dataSendingStarted <= '1';
				end if;
			end if;
		end if;
	end process;
end architecture rtl;

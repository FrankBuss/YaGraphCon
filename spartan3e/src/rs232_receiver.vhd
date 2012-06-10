-- Copyright (c) 2009 Frank Buss (fb@frank-buss.de)
-- See license.txt for license
--
-- Simple RS232 receiver with generic, baudrate and 8N1 mode.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
USE work.all;

entity rs232_receiver is
	generic(
		-- clock frequency, in hz
		SYSTEM_SPEED,
		
		-- baudrate, in bps
		BAUDRATE: integer
	);  
	port(
		clock: in std_logic;
		reset: in std_logic;
		
		-- received RS232 data
		data: out unsigned(7 downto 0);
		
		-- RS232 RX pin
		rx: in std_logic;
		
		-- this is set for one clock pulse to 1, when the data was received
		dataReceived: out std_logic
	);
end entity rs232_receiver;

architecture rtl of rs232_receiver is
	constant MAX_COUNTER: natural := SYSTEM_SPEED / BAUDRATE;
	signal baudrateCounter: natural range 0 to MAX_COUNTER := 0;
  
	type stateType is (
		WAIT_FOR_RX_START, 
		WAIT_HALF_BIT,
		RECEIVE_BITS,
		WAIT_FOR_STOP_BIT
	);

	signal state: stateType := WAIT_FOR_RX_START;
	signal bitCounter: natural range 0 to 7 := 0;
	signal shiftRegister: unsigned(7 downto 0) := (others => '0');
	signal rxLatch: std_logic;

begin

	update: process(clock, reset)
	begin
		if rising_edge(clock) then
			dataReceived <= '0';
			rxLatch <= rx;
			if reset = '1' then
				state <= WAIT_FOR_RX_START;
				data <= (others => '0');
			else
				case state is
					when WAIT_FOR_RX_START =>
						if rxLatch = '0' then
							-- start bit received, wait for a half bit time
							-- to sample bits in the middle of the signal
							state <= WAIT_HALF_BIT;
							baudrateCounter <= MAX_COUNTER / 2 - 1;
						end if;
					when WAIT_HALF_BIT =>
						if baudrateCounter = 0 then
							-- now we are in the middle of the start bit,
							-- wait a full bit for the middle of the first bit
							state <= RECEIVE_BITS;
							bitCounter <= 7;
							baudrateCounter <= MAX_COUNTER - 1;
						else
							baudrateCounter <= baudrateCounter - 1;
						end if;
					when RECEIVE_BITS =>
						-- sample a bit
						if baudrateCounter = 0 then
							shiftRegister <= rxLatch & shiftRegister(7 downto 1);
							if bitCounter = 0 then
								state <= WAIT_FOR_STOP_BIT;
							else
								bitCounter <= bitCounter - 1;
							end if;
							baudrateCounter <= MAX_COUNTER - 1;
						else
							baudrateCounter <= baudrateCounter - 1;
						end if;
					when WAIT_FOR_STOP_BIT =>
						-- wait for the middle of the stop bit
						if baudrateCounter = 0 then
							state <= WAIT_FOR_RX_START;
							if rxLatch = '1' then
								data <= shiftRegister;
								dataReceived <= '1';
								-- else: missing stop bit, ignore
							end if;  
						else
							baudrateCounter <= baudrateCounter - 1;
						end if;
				end case;
			end if;
		end if;
	end process;

end architecture rtl;

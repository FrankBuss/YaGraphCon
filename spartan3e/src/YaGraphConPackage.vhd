-- Copyright (c) 2009 Frank Buss (fb@frank-buss.de)
-- See license.txt for license

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package YaGraphConPackage is
	constant RESET_COMMAND: unsigned(7 downto 0) := x"00";
	constant SET_FRAMEBUFFER_START: unsigned(7 downto 0) := x"01";
	constant SET_FRAMEBUFFER_PITCH: unsigned(7 downto 0) := x"02";
	constant SET_DESTINATION_START: unsigned(7 downto 0) := x"03";
	constant SET_DESTINATION_PITCH: unsigned(7 downto 0) := x"04";
	constant SET_SOURCE_START: unsigned(7 downto 0) := x"05";
	constant SET_SOURCE_PITCH: unsigned(7 downto 0) := x"06";
	constant SET_COLOR: unsigned(7 downto 0) := x"07";
	constant SET_PIXEL: unsigned(7 downto 0) := x"08";
	constant MOVE_TO: unsigned(7 downto 0) := x"09";
	constant LINE_TO: unsigned(7 downto 0) := x"0a";
	constant FILL_RECT: unsigned(7 downto 0) := x"0b";
	constant BLIT_SIZE: unsigned(7 downto 0) := x"0c";
	constant BLIT_COMMAND: unsigned(7 downto 0) := x"0d";
	constant BLIT_TRANSPARENT: unsigned(7 downto 0) := x"0e";
	constant WRITE_FRAMEBUFFER: unsigned(7 downto 0) := x"0f";

	function adjustLength(value: unsigned; length: natural) return unsigned;
	function max(left, right: natural) return natural;
	function min(left, right: natural) return natural;
end;

package body YaGraphConPackage is
	function adjustLength(value: unsigned; length: natural) return unsigned is
		variable result: unsigned(length-1 downto 0);
	begin
		if value'length >= length then
			result := value(length-1 downto 0);
		else
			result := to_unsigned(0, length - value'length) & value;
		end if;
		return result;
	end;

	function max(left, right: natural) return natural is
	begin
		if left > right then
			return left;
		else
			return right;
		end if;
	end;

	function min(left, right: natural) return natural is
	begin
		if left < right then
			return left;
		else
			return right;
		end if;
	end;
end;

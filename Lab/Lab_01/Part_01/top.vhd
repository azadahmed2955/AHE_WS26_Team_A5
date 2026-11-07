library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity top is
    port (
        sw  : in  STD_LOGIC_VECTOR(15 downto 0);
        led : out STD_LOGIC_VECTOR(15 downto 0)
    );
end top;

architecture rtl of top is
begin
    led <= sw;
end rtl;
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_pwm is
end entity tb_pwm;

architecture sim of tb_pwm is
    constant W : positive := 4;

    signal clk     : std_logic := '0';
    signal rst_n   : std_logic := '0';
    signal enable  : std_logic := '0';
    signal duty    : unsigned(W-1 downto 0) := to_unsigned(15, W);
    signal pwm_out : std_logic;
begin
    clk <= not clk after 5 ns;

    dut : entity work.pwm_core
        generic map (
            G_WIDTH => W
        )
        port map (
            clk     => clk,
            rst_n   => rst_n,
            enable  => enable,
            duty    => duty,
            pwm_out => pwm_out
        );

    process
        variable n : natural := 0;
    begin
        wait for 20 ns;
        rst_n  <= '1';
        enable <= '1';

        for i in 1 to 16 loop
            wait until rising_edge(clk);
            wait for 1 ns;

            if pwm_out = '1' then
                n := n + 1;
            end if;
        end loop;

        assert n = 15
            report "Duty error: expected 15 high cycles, got "
                   & integer'image(n)
            severity failure;

        report "TEST PASSED: duty = 15" severity note;
        wait;
    end process;
end architecture sim;
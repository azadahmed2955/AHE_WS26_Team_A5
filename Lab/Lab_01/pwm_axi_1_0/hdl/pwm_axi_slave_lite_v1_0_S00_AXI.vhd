library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity pwm_axi_slave_lite_v1_0_S00_AXI is
    generic (
        C_S_AXI_DATA_WIDTH : integer := 32;
        C_S_AXI_ADDR_WIDTH : integer := 4
    );
    port (
        -- PWM outputs
        pwm_r : out std_logic;
        pwm_g : out std_logic;
        pwm_b : out std_logic;

        -- AXI clock and active-low reset
        S_AXI_ACLK    : in std_logic;
        S_AXI_ARESETN : in std_logic;

        -- Write address channel
        S_AXI_AWADDR  : in std_logic_vector(
            C_S_AXI_ADDR_WIDTH-1 downto 0);
        S_AXI_AWPROT  : in std_logic_vector(2 downto 0);
        S_AXI_AWVALID : in std_logic;
        S_AXI_AWREADY : out std_logic;

        -- Write data channel
        S_AXI_WDATA   : in std_logic_vector(
            C_S_AXI_DATA_WIDTH-1 downto 0);
        S_AXI_WSTRB   : in std_logic_vector(
            (C_S_AXI_DATA_WIDTH/8)-1 downto 0);
        S_AXI_WVALID  : in std_logic;
        S_AXI_WREADY  : out std_logic;

        -- Write response channel
        S_AXI_BRESP   : out std_logic_vector(1 downto 0);
        S_AXI_BVALID  : out std_logic;
        S_AXI_BREADY  : in std_logic;

        -- Read address channel
        S_AXI_ARADDR  : in std_logic_vector(
            C_S_AXI_ADDR_WIDTH-1 downto 0);
        S_AXI_ARPROT  : in std_logic_vector(2 downto 0);
        S_AXI_ARVALID : in std_logic;
        S_AXI_ARREADY : out std_logic;

        -- Read data channel
        S_AXI_RDATA   : out std_logic_vector(
            C_S_AXI_DATA_WIDTH-1 downto 0);
        S_AXI_RRESP   : out std_logic_vector(1 downto 0);
        S_AXI_RVALID  : out std_logic;
        S_AXI_RREADY  : in std_logic
    );
end entity pwm_axi_slave_lite_v1_0_S00_AXI;

architecture arch_imp of pwm_axi_slave_lite_v1_0_S00_AXI is

    -- Register map:
    -- 0x00: CTRL, bit 0 enables all channels
    -- 0x04: Red duty, bits 7:0
    -- 0x08: Green duty, bits 7:0
    -- 0x0C: Blue duty, bits 7:0

    type register_array_t is array (0 to 3) of
        std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);

    signal regs : register_array_t :=
        (others => (others => '0'));

    -- Separate buffers for write address and write data
    signal awaddr_saved : std_logic_vector(
        C_S_AXI_ADDR_WIDTH-1 downto 0);
    signal wdata_saved : std_logic_vector(
        C_S_AXI_DATA_WIDTH-1 downto 0);
    signal wstrb_saved : std_logic_vector(
        (C_S_AXI_DATA_WIDTH/8)-1 downto 0);

    signal aw_pending : std_logic := '0';
    signal w_pending  : std_logic := '0';

    signal axi_awready : std_logic;
    signal axi_wready  : std_logic;
    signal axi_bvalid  : std_logic := '0';

    signal axi_arready : std_logic;
    signal axi_rvalid  : std_logic := '0';
    signal axi_rdata  : std_logic_vector(
        C_S_AXI_DATA_WIDTH-1 downto 0) := (others => '0');

begin

    assert C_S_AXI_DATA_WIDTH = 32
        report "This PWM peripheral requires a 32-bit AXI data bus"
        severity failure;

    assert C_S_AXI_ADDR_WIDTH >= 4
        report "AXI address width must be at least 4"
        severity failure;

    -- Accept one write transaction at a time.
    axi_awready <= '1'
        when S_AXI_ARESETN = '1'
         and aw_pending = '0'
         and axi_bvalid = '0'
        else '0';

    axi_wready <= '1'
        when S_AXI_ARESETN = '1'
         and w_pending = '0'
         and axi_bvalid = '0'
        else '0';

    S_AXI_AWREADY <= axi_awready;
    S_AXI_WREADY  <= axi_wready;
    S_AXI_BVALID  <= axi_bvalid;
    S_AXI_BRESP   <= "00";  -- OKAY

    -- Read response stays valid until accepted.
    axi_arready <= '1'
        when S_AXI_ARESETN = '1'
         and axi_rvalid = '0'
        else '0';

    S_AXI_ARREADY <= axi_arready;
    S_AXI_RVALID  <= axi_rvalid;
    S_AXI_RDATA   <= axi_rdata;
    S_AXI_RRESP   <= "00";  -- OKAY

    -- AXI write logic
    process(S_AXI_ACLK)
        variable reg_index : integer range 0 to 3;
    begin
        if rising_edge(S_AXI_ACLK) then
            if S_AXI_ARESETN = '0' then
                regs         <= (others => (others => '0'));
                awaddr_saved <= (others => '0');
                wdata_saved  <= (others => '0');
                wstrb_saved  <= (others => '0');
                aw_pending   <= '0';
                w_pending    <= '0';
                axi_bvalid   <= '0';
            else
                -- Capture write address independently.
                if S_AXI_AWVALID = '1'
                   and axi_awready = '1' then
                    awaddr_saved <= S_AXI_AWADDR;
                    aw_pending   <= '1';
                end if;

                -- Capture write data independently.
                if S_AXI_WVALID = '1'
                   and axi_wready = '1' then
                    wdata_saved <= S_AXI_WDATA;
                    wstrb_saved <= S_AXI_WSTRB;
                    w_pending   <= '1';
                end if;

                -- Complete the write once both are buffered.
                if aw_pending = '1'
                   and w_pending = '1'
                   and axi_bvalid = '0' then

                    reg_index :=
                        to_integer(unsigned(awaddr_saved(3 downto 2)));

                    for byte_index in
                        0 to (C_S_AXI_DATA_WIDTH/8)-1 loop

                        if wstrb_saved(byte_index) = '1' then
                            regs(reg_index)(
                                byte_index*8+7 downto byte_index*8)
                            <= wdata_saved(
                                byte_index*8+7 downto byte_index*8);
                        end if;
                    end loop;

                    aw_pending <= '0';
                    w_pending  <= '0';
                    axi_bvalid <= '1';

                elsif axi_bvalid = '1'
                      and S_AXI_BREADY = '1' then
                    axi_bvalid <= '0';
                end if;
            end if;
        end if;
    end process;

    -- AXI read logic
    process(S_AXI_ACLK)
        variable reg_index : integer range 0 to 3;
    begin
        if rising_edge(S_AXI_ACLK) then
            if S_AXI_ARESETN = '0' then
                axi_rvalid <= '0';
                axi_rdata  <= (others => '0');
            else
                if S_AXI_ARVALID = '1'
                   and axi_arready = '1' then

                    reg_index :=
                        to_integer(unsigned(S_AXI_ARADDR(3 downto 2)));

                    axi_rdata  <= regs(reg_index);
                    axi_rvalid <= '1';

                elsif axi_rvalid = '1'
                      and S_AXI_RREADY = '1' then
                    axi_rvalid <= '0';
                end if;
            end if;
        end if;
    end process;

    -- Red PWM channel
    pwm_red : entity work.pwm_core
        generic map (
            G_WIDTH => 8
        )
        port map (
            clk     => S_AXI_ACLK,
            rst_n   => S_AXI_ARESETN,
            enable  => regs(0)(0),
            duty    => unsigned(regs(1)(7 downto 0)),
            pwm_out => pwm_r
        );

    -- Green PWM channel
    pwm_green : entity work.pwm_core
        generic map (
            G_WIDTH => 8
        )
        port map (
            clk     => S_AXI_ACLK,
            rst_n   => S_AXI_ARESETN,
            enable  => regs(0)(0),
            duty    => unsigned(regs(2)(7 downto 0)),
            pwm_out => pwm_g
        );

    -- Blue PWM channel
    pwm_blue : entity work.pwm_core
        generic map (
            G_WIDTH => 8
        )
        port map (
            clk     => S_AXI_ACLK,
            rst_n   => S_AXI_ARESETN,
            enable  => regs(0)(0),
            duty    => unsigned(regs(3)(7 downto 0)),
            pwm_out => pwm_b
        );

end architecture arch_imp;
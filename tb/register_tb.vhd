library ieee;
use ieee.STD_LOGIC_1164.all;
use ieee.numeric_std.all;

entity register_flip_flop_d_tb is
end register_flip_flop_d_tb;

architecture behavioural of register_flip_flop_d_tb is
    -- Constant
    constant DATA_WIDTH : integer := 4;
    constant RESET_VAL  : STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0) :=  (others => '0');
    -- DUT signals
    signal clk          : STD_LOGIC;
    signal areset_n     : STD_LOGIC;
    signal d            : STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0);
    signal q            : STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0);

begin
    -- Instantiate DUT
    DUT: entity work.register_flip_flop_d_struct
    -- DUT: entity work.register_flip_flop_d_beh
        generic map (
            RESET_VAL  => RESET_VAL,
            DATA_WIDTH => DATA_WIDTH
        )
        port map (
            d        => d,
            clk      => clk,
            areset_n => areset_n,
            q        => q
        );

    -- Clock Generation Process
    clk_gen: process
    begin
        clk <= '0';
        wait for 10 ns;
        clk <= '1';
        wait for 10 ns;
    end process clk_gen;

    -- Stimulus Process
    stim_proc: process
    begin
        -- Case 0: Apply Asynchronous Reset (Expected result is RESET_VAL for all bits)
        areset_n <= '0';
        d        <= (others => '0');
        wait for 10 ns;
        assert (q = RESET_VAL)
            report "[TB] Fail areset_n = 0, q != RESET_VAL"
            severity error;

        -- Case 1: Release Reset and test data propagation
        areset_n <= '1';
        -- For each representable value
        for i in 0 to (2**DATA_WIDTH - 1) loop
            d <= STD_LOGIC_VECTOR(to_unsigned(i, DATA_WIDTH));
            wait until rising_edge(clk);
            assert (q = d)
                report "[TB] Fail areset_n = 1, d = " & integer'image(i) & ", q mismatch"
                severity error;
        end loop;

        -- Case 2: Verify Asynchronous Reset during mid-operation
        d        <= (others => '0');
        wait for 10 ns;
        areset_n <= '0';
        wait for 10 ns;
        assert (q = RESET_VAL)
            report "[TB] Fail areset_n = 0 mid-op, q != RESET_VAL"
            severity error;

        -- End simulation
        report "[TB] Simulation ending";
        std.env.finish;
    end process;
end behavioural;
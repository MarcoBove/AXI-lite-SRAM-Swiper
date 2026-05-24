library ieee;
use ieee.STD_LOGIC_1164.all;
use ieee.numeric_std.all;

entity counter_tb is
end counter_tb;

--MODIFICARE per mettere il segnale di clear
architecture behavioural of counter_tb is

    -- Signals declared without initialization
    constant DATA_WIDTH : integer := 4;
    constant RESET_VAL : STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0) := ( others => '0');

    -- Signals for DUT ports
    signal clk      : STD_LOGIC;
    signal areset_n : STD_LOGIC;
    signal enable       : STD_LOGIC;
    signal q        : STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0);

begin
    -- Instantiate DUT
     DUT: entity work.counter
    --DUT: entity work.counter_struct
        generic map (
            DATA_WIDTH => DATA_WIDTH
        )
        port map (
            clk      => clk,
            areset_n => areset_n,
            enable   => enable,
            q        => q
        );

    -- Clock Generation: 20ns period (10ns low, 10ns high)
    clk_gen: process
    begin
        clk <= '0';
        wait for 10 ns;
        clk <= '1';
        wait for 10 ns;
    end process clk_gen;

    -- Stimulus Process
    stim_proc: process
        -- Local variable for expected state tracking
        variable v_expected_q : unsigned(DATA_WIDTH-1 downto 0);
    begin
        -- Initial Reset
        areset_n <= '0';
        enable       <= '0';
        wait for 20 ns;
        -- Assert on reset state
        assert (q = RESET_VAL)
            report "[TB] Fail initial reset q=" & to_string(q)
            severity error;

        areset_n <= '1';
        v_expected_q := (others => '0');
        wait for 10 ns;

        -- Exhaustive Loop: Iterate through the entire count range
        COUNT_CYCLE: for i in 0 to (2**DATA_WIDTH - 1) loop

            -- 1. Disable Check: Verify stability when enable=0
            enable <= '0';
            wait until rising_edge(clk);
            wait for 5 ns; -- Propagation delay check
            assert (unsigned(q) = v_expected_q)
                report "[TB] Fail: Count changed while enable=0, q=" & to_string(q) &
                    " v_expected_q=" & to_string(v_expected_q)
                severity error;

            -- 2. Enable Check: Verify increment when enable=1
            enable <= '1';
            wait until rising_edge(clk);
            wait for 5 ns; -- Propagation delay check

            -- Update our local expected tracking
            v_expected_q := v_expected_q + 1;

            assert (unsigned(q) = v_expected_q)
                report "[TB] Fail: Counter mismatch. " &
                       "Expected=" & to_string(v_expected_q) &
                       " Got=" & to_string(q)
                severity error;

        end loop COUNT_CYCLE;

        -- End simulation
        report "[TB] Simulation ending";
        std.env.finish;
    end process stim_proc;

end behavioural;
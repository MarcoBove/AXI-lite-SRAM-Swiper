library ieee;
use ieee.STD_LOGIC_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity sram_tb is
end sram_tb;

architecture behavioural of sram_tb is

    -- Configuration Constants
    constant RESET_VAL   : STD_LOGIC := '1';
    constant NUM_WORDS   : integer := 16;
    constant DATA_WIDTH  : integer := 32;
    constant ADDR_WIDTH  : integer := integer(ceil(log2(real(NUM_WORDS))));
    constant NUM_BYTES   : integer := DATA_WIDTH/8;

    -- DUT Signals
    signal clk      : STD_LOGIC;
    signal areset_n : STD_LOGIC;
    signal cs       : STD_LOGIC;
    signal we       : STD_LOGIC_VECTOR(NUM_BYTES-1 downto 0);
    signal addr     : STD_LOGIC_VECTOR(ADDR_WIDTH-1 downto 0) := (others => '0'); -- Reset this to avoid simulation 'U'
    signal wdata    : STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0);
    signal rdata    : STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0);

begin

    -- Instantiate DUT
    DUT: entity work.sram
        generic map (
            RESET_VAL  => RESET_VAL,
            NUM_WORDS  => NUM_WORDS,
            DATA_WIDTH => DATA_WIDTH
        )
        port map (
            clk      => clk,
            areset_n => areset_n,
            cs       => cs,
            we       => we,
            addr     => addr,
            wdata    => wdata,
            rdata    => rdata
        );

    -- Clock Generation: 20ns period
    clk_gen: process
    begin
        clk <= '0'; wait for 10 ns;
        clk <= '1'; wait for 10 ns;
    end process clk_gen;

    -- Stimulus Process
    stim_proc: process
        -- Mirror of the specific word we are testing to calculate expected value
        variable v_mem_expected : STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0);
        variable v_write_data   : STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0);
        -- Constant expected reset word
        constant v_RESET_WORD   : STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0) := (others => RESET_VAL);
    begin
        -- Initial Reset
        areset_n <= '0';
        cs       <= '0';
        we       <= (others => '0');
        addr     <= (others => '0');
        wdata    <= (others => '0');
        wait for 40 ns;
        areset_n <= '1';
        wait for 20 ns;

        -- Verify reset
        cs <= '1'; -- Enable chip for reading
        RESET_VERIF_LOOP: for i in 0 to NUM_WORDS-1 loop
            addr <= STD_LOGIC_VECTOR(to_unsigned(i, ADDR_WIDTH));
            wait for 10 ns;

            -- Check read data against expected reset
            assert (rdata = v_RESET_WORD)
                report "[TB] Reset Fail at Addr: 0x" & integer'image(i) &
                       " Read value: " & to_string(rdata) &
                       " Expected: " & to_string(v_RESET_WORD)
                severity error;
        end loop RESET_VERIF_LOOP;

        -- Disable across tests
        cs <= '0';

        -- Wait across tests
        wait for 10 ns;

        -- For each address
        ADDRESS_LOOP: for i in 0 to NUM_WORDS-1 loop
            -- Convert to STD_LOGIC_VECTOR
            addr <= STD_LOGIC_VECTOR(to_unsigned(i, ADDR_WIDTH));

            -- Enable chip select
            cs   <= '1';

            -- Initialize expected value after reset
            v_mem_expected := (others => RESET_VAL);

            -- Inner Loop: Test every possible Write Enable combination (0 to 15 for 4 bytes)
            WE_LOOP: for j in 0 to (2**NUM_BYTES - 1) loop

                -- Generate unique test data for this specific write attempt
                -- e.g., 0xAAAA5555, 0x12345678, etc.
                v_write_data := STD_LOGIC_VECTOR(to_unsigned(i + j + 16#A5#, DATA_WIDTH));

                -- Set Write Enable and Data In
                we  <= STD_LOGIC_VECTOR(to_unsigned(j, NUM_BYTES));
                wdata <= v_write_data;

                wait until rising_edge(clk);

                -- Update the local variable mirror to calculate the "Expected" value
                -- based on which byte-enables were active
                for b in 0 to NUM_BYTES-1 loop
                    if we(b) = '1' then
                        v_mem_expected((b*8)+7 downto b*8) := v_write_data((b*8)+7 downto b*8);
                    end if;
                end loop;

                -- Disable writes
                we <= (others => '0');

                assert (rdata = v_mem_expected)
                    report "[TB] Error at Addr: " & integer'image(i) &
                           " WE: " & to_string(we) &
                           " Expected: " & to_string(v_mem_expected) &
                           " Got: " & to_string(rdata)
                    severity error;

            end loop WE_LOOP;
        end loop ADDRESS_LOOP;

        report "[TB] Simulation ending";
        std.env.finish;
    end process stim_proc;

end behavioural;
library ieee;
use ieee.STD_LOGIC_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity sram is
    generic (
        RESET_VAL  : STD_LOGIC := '0';
        NUM_WORDS  : integer := 256;
        DATA_WIDTH : integer := 32
    );
    port (
        -- Clock and reset
        clk      : in  STD_LOGIC;
        areset_n : in  STD_LOGIC;
        -- Chip Select
        cs       : in  STD_LOGIC;
        -- Address
        addr     : in  STD_LOGIC_VECTOR(integer(ceil(log2(real(NUM_WORDS))))-1 downto 0);
        -- Write Enable (byte-wise)
        we       : in  STD_LOGIC_VECTOR((DATA_WIDTH/8)-1 downto 0);
        -- Write data
        wdata    : in  STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0);
        -- Read data
        rdata    : out STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0)
    );
end sram;

architecture behavioural of sram is

    -- Internal memory array type NUM_WORDS x DATA_WIDTH
    type memory_array_t is array (NUM_WORDS-1 downto 0) of STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0);

    -- Memory signal initialized to zero
    signal ram : memory_array_t := (others => (others => RESET_VAL));

begin

    -- Asynchronous data read, regadless of CS
    rdata <= ram(to_integer(unsigned(addr)));
    -- Tied-off on not chip select
    -- rdata <= ram(to_integer(unsigned(addr))) when cs = '1' else (others => '0');
    -- High-impedance for shared buses
    -- rdata <= ram(to_integer(unsigned(addr))) when cs = '1' else (others => 'Z');

    -- Write Process
    write_proc: process (clk)
        -- Integer index from STD_LOGIC_VECTOR address
        variable v_addr_idx : integer;
    begin
        if areset_n = '0' then
            -- Asynchronous Reset: Clear all memory locations
            ram <= (others => (others => RESET_VAL));
        elsif rising_edge(clk) then
            -- If chip select
            CS_IF: if cs = '1' then
                -- Defensive check for address range
                assert (v_addr_idx < NUM_WORDS)
                    report "[ERROR] v_addr_idx (" & to_String(v_addr_idx) & ") > " &
                        " DATA_WIDTH (" & integer'image(DATA_WIDTH) & ")"
                    severity failure;

                -- Convert to integer
                v_addr_idx := to_integer(unsigned(addr));

                -- For each byte
                BYTE_LOOP: for i in 0 to (DATA_WIDTH/8)-1 loop
                    -- If write enable
                    WRITE_EN: if we(i) = '1' then
                        -- Write byte in word
                        ram(v_addr_idx)((i*8)+7 downto i*8) <= wdata((i*8)+7 downto i*8);
                    end if WRITE_EN;
                end loop BYTE_LOOP;
            end if CS_IF;
        end if;
    end process write_proc;

end behavioural;
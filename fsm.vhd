library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity SRAM_Swiper_FSM is
    port (
        -- Clock and Reset
        clk             : in  std_logic;
        areset_n        : in  std_logic;

        -- Interfaccia dai Registri AXI (Input)
        -- Nota: collegheremo questi ai slv_regX del modulo AXI
        src_addr_in     : in  std_logic_vector(31 downto 0);
        num_w_in        : in  std_logic_vector(31 downto 0);
        preload_start   : in  std_logic; -- Impulso di start per preload
        swipe_start     : in  std_logic; -- Impulso di start per lo swipe

        -- Interfaccia verso i Registri AXI (Output di Stato)
        preload_done    : out std_logic;
        swipe_done      : out std_logic;

        -- Interfaccia Master verso la SRAM
        sram_addr       : out std_logic_vector(31 downto 0);
        sram_wdata      : out std_logic_vector(31 downto 0);
        sram_rdata      : in  std_logic_vector(31 downto 0);
        sram_we         : out std_logic_vector(3 downto 0); -- 4 bit per gestire i byte
        sram_en         : out std_logic
    );
end SRAM_Swiper_FSM;


architecture behavioural of SRAM_Swiper_FSM  is

    component counter is
        generic (
            DATA_WIDTH : integer := 32
        );
        port (
            clk      : in  STD_LOGIC;
            areset_n : in  STD_LOGIC;
            clear    : in  STD_LOGIC;
            en       : in  STD_LOGIC;
            q        : out STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0)
        );
    end component;

    -- Enumerative type for FSM state
    type state_t is (
        IDLE,
        PRELOAD_WRITE,
        PRELOAD_UPDATE,
        PRELOAD_FINISH
    );

    -- State register
    signal state_q, state_d: state_t;

    -- Datapath Counter Registers
    signal sig_cnt_q : std_logic_vector(31 downto 0);
    signal sig_cnt_en : std_logic;
    signal sig_cnt_clear : std_logic;

begin
    --Instance
    i_address_counter: counter
        generic map (
            DATA_WIDTH => 32
        )
        port map (
            clk      => clk,
            areset_n => areset_n,
            clear    => sig_cnt_clear,
            en       => sig_cnt_en,   
            q        => sig_cnt_q      
        );

    -- Moore Output: Only depends on the state

        sram_wdata <= x"AAAA5555"; --101010101010...

        sram_addr <= sig_cnt_q;

        sram_en <= '1' when state_q = PRELOAD_WRITE else '0';
        sram_we <= "1111" when state_q = PRELOAD_WRITE else "0000";
        preload_done <= '1' when state_q = PRELOAD_FINISH else '0';

        sig_cnt_clear <= '1' when state_q = IDLE else '0';
        sig_cnt_en <= '1' when state_q = PRELOAD_UPDATE else '0';

        swipe_done <= '0';
        

    -- Next state logic
    next_state_proc: process(state_q, preload_start, num_w_in, sig_cnt_q) --qua poi mettere swipe_start
    begin
        state_d <= state_q; -- Default: rimani nello stato attuale

        case state_q is
            when IDLE =>
                if preload_start = '1' then
                    state_d <= PRELOAD_WRITE;
                end if;

            when PRELOAD_WRITE =>
                state_d <= PRELOAD_UPDATE;
            
            when PRELOAD_UPDATE =>
                if(unsigned(sig_cnt_q) = unsigned(num_w_in) - 1) then -- qua devo mettere un adder
                    state_d <= PRELOAD_FINISH;
                else
                    state_d <= PRELOAD_WRITE;
                end if;

            when PRELOAD_FINISH =>
                state_d <= IDLE;
            
            when others =>
                state_d <= IDLE;
        end case;
    end process next_state_proc;

    -- Memory Process
    reg_proc: process(clk, areset_n)
    begin
        if areset_n = '0' then
            state_q <= IDLE;
        elsif rising_edge(clk) then
            state_q <= state_d;
        end if;
    end process reg_proc;

    -- Debug process: log incoming sequence
    -- log_proc: process (clk, areset_n)
    --     constant LOG_DEPTH : integer := 64;
    --     variable v_log : STD_LOGIC_VECTOR( LOG_DEPTH -1 downto 0 );
    -- begin
    --     -- On clock edge
    --     if rising_edge(clk) then
    --         -- Shift in data_in and shift right the rest
    --         v_log(LOG_DEPTH-1 downto 0) := data_in & v_log(LOG_DEPTH-1 downto 1);
    --         -- Dump
    --         report "[DEBUG] v_log: " & to_string(v_log);
    --     end if;
    -- end process log_proc;

end behavioural;
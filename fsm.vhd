library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity SRAM_Swiper_FSM is
    generic (
        DATA_WIDTH      : integer := 32;
        WE_DATA_WIDTH   : integer := 4
    );
    port (
        -- Clock and Reset
        clk             : in  std_logic;
        areset_n        : in  std_logic;

        -- Interface from AXI Registers (Input)
        src_addr_in     : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        num_w_in        : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        preload_start   : in  std_logic; 
        swipe_start     : in  std_logic; 

        -- Interface to AXI Registers ( State Output)
        preload_done    : out std_logic;
        swipe_done      : out std_logic;

        -- Master Interface to SRAM
        sram_addr       : out std_logic_vector(DATA_WIDTH-1 downto 0);
        sram_wdata      : out std_logic_vector(DATA_WIDTH-1 downto 0);
        sram_rdata      : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        sram_we         : out std_logic_vector(WE_DATA_WIDTH-1 downto 0);
        sram_en         : out std_logic
    );
end SRAM_Swiper_FSM;


architecture behavioural of SRAM_Swiper_FSM is
-- Component Declaration
    component counter is
        generic (
            DATA_WIDTH : integer 
        );
        port (
            clk      : in  STD_LOGIC;
            areset_n : in  STD_LOGIC;
            clear    : in  STD_LOGIC;
            en       : in  STD_LOGIC;
            load     : in  STD_LOGIC;
            d_in     : in  STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0);
            q        : out STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0)
        );
    end component;

    component register_flip_flop_d_beh is
        generic (
            DATA_WIDTH : integer ;
            RESET_VAL  : STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0) := (others => '0')
        );
        port (
            clk      : in  STD_LOGIC;
            areset_n : in  STD_LOGIC;
            d        : in  STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0);
            q        : out STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0)
        );
    end component;

    component incrementer is
        generic(
            DATA_WIDTH : integer := 32 
        );
        port (
            d_in  : in  std_logic_vector(DATA_WIDTH-1 downto 0);
            d_out : out std_logic_vector(DATA_WIDTH-1 downto 0)
        );
    end component;

    component comparator is
        generic(
            DATA_WIDTH : integer := 32 
        );
        port (
            current_cnt : in  std_logic_vector(DATA_WIDTH-1 downto 0);
            start_addr  : in  std_logic_vector(DATA_WIDTH-1 downto 0);
            num_words   : in  std_logic_vector(DATA_WIDTH-1 downto 0);
            is_done     : out std_logic
        );
    end component;

    -- Type of FSM
    type state_t is (
        IDLE,
        -- Preload
        PRELOAD_WRITE,
        PRELOAD_UPDATE,
        PRELOAD_FINISH,
        -- Swipe
        SWIPE_INIT,
        SWIPE_READ,
        SWIPE_WRITE,
        SWIPE_UPDATE,
        SWIPE_FINISH
    );

    -- State register
    signal state_q, state_d: state_t;

    -- Datapath Counter & Register Signals
    signal sig_cnt_q            : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
    signal sig_cnt_en           : std_logic;
    signal sig_cnt_clear        : std_logic;
    signal sig_cnt_load         : std_logic;
    signal sig_mod_data_in      : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal sig_mod_data_out     : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal sig_base_addr        : std_logic_vector(DATA_WIDTH-1 downto 0);

    signal sig_incremented_data : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal sig_is_done          : std_logic;

begin

    -- Address Counter Istance
    i_address_counter: counter
        generic map (
            DATA_WIDTH => DATA_WIDTH
        )
        port map (
            clk      => clk,
            areset_n => areset_n,
            clear    => sig_cnt_clear,
            en       => sig_cnt_en,
            load     => sig_cnt_load, 
            d_in     => src_addr_in,   
            q        => sig_cnt_q      
        );

    -- Swipe Data Register Istance
    i_mod_register: register_flip_flop_d_beh
        generic map (
            DATA_WIDTH => DATA_WIDTH,
            RESET_VAL  => (others => '0')
        )
        port map (
            clk      => clk,
            areset_n => areset_n,
            d        => sig_mod_data_in,
            q        => sig_mod_data_out
        );

    -- Incrementer Istance
    i_incrementer: incrementer
        generic map (
            DATA_WIDTH  => DATA_WIDTH
        )
        port map (
            d_in    => sram_rdata,
            d_out   => sig_incremented_data
        );

    -- Comparator Istance    
    i_comparator : comparator
        generic map (
            DATA_WIDTH   => DATA_WIDTH
        )
        port map (
            current_cnt  => sig_cnt_q,
            start_addr   => sig_base_addr,
            num_words    => num_w_in,
            is_done      => sig_is_done
        );

    ----------------------------------------------------------------------------
    -- MOORE OUTPUTS: DATAPATH & CONTROL SIGNALS
    ----------------------------------------------------------------------------
    
    -- Address and Data Management To SRAM
    sram_addr  <= sig_cnt_q;
    sram_wdata <= sig_cnt_q when (state_q = PRELOAD_WRITE) else sig_mod_data_out;
    
    -- Memory Enable: Active in Preload write, and in Swipe read/write
    sram_en <= '1' when (state_q = PRELOAD_WRITE or state_q = SWIPE_READ or state_q = SWIPE_WRITE) else '0';
    
    -- Write Enable: only when the data is written
    sram_we <= "1111" when (state_q = PRELOAD_WRITE or state_q = SWIPE_WRITE) else "0000";

    -- Signals to Output
    preload_done <= '1' when state_q = PRELOAD_FINISH else '0';
    swipe_done   <= '1' when state_q = SWIPE_FINISH   else '0';

    -- Controllo Contatore
    -- Check Counters
    sig_cnt_clear <= '1' when state_q = IDLE else '0';
    sig_cnt_load  <= '1' when state_q = SWIPE_INIT else '0';
    sig_cnt_en    <= '1' when (state_q = PRELOAD_UPDATE or state_q = SWIPE_UPDATE) else '0';

    --Choosing the base address based on the operation
    sig_base_addr <= (others => '0') when (state_q = PRELOAD_UPDATE) else src_addr_in;

    -- The register input data comes from Incrementer
    sig_mod_data_in <= sig_incremented_data when (state_q = SWIPE_READ) else sig_mod_data_out;


    ----------------------------------------------------------------------------
    -- NEXT STATE LOGIC
    ----------------------------------------------------------------------------

    next_state_proc: process(state_q, preload_start, swipe_start, num_w_in, src_addr_in, sig_cnt_q)
    begin
        state_d <= state_q; -- Default

        case state_q is
            when IDLE =>
                if preload_start = '1' then
                    state_d <= PRELOAD_WRITE;
                elsif swipe_start = '1' then
                    state_d <= SWIPE_INIT;
                end if;

            -- ==========================
            --  1: PRELOAD
            -- ==========================
            when PRELOAD_WRITE =>
                state_d <= PRELOAD_UPDATE;
            
            when PRELOAD_UPDATE =>
                --Check num_w_in words
                if sig_is_done = '1' then 
                    state_d <= PRELOAD_FINISH;
                else
                    state_d <= PRELOAD_WRITE;
                end if;

            when PRELOAD_FINISH =>
                if preload_start = '0' then
                    state_d <= IDLE;
                end if;
            
            -- ==========================
            --  2: SWIPE
            -- ==========================
            when SWIPE_INIT =>
                -- READ
                state_d <= SWIPE_READ;
                
            when SWIPE_READ =>
                -- WRITE
                state_d <= SWIPE_WRITE;
                
            when SWIPE_WRITE =>
                -- UPDATE ADDRESS
                state_d <= SWIPE_UPDATE;
                
            when SWIPE_UPDATE =>
                -- Check the final address
                if sig_is_done = '1'  then
                    state_d <= SWIPE_FINISH;
                else
                    state_d <= SWIPE_READ;
                end if;

            when SWIPE_FINISH =>
                if swipe_start = '0' then
                    state_d <= IDLE;
                end if;

            -- ==========================
            -- SAFETY CATCH
            -- ==========================
            when others =>
                state_d <= IDLE;
        end case;
    end process next_state_proc;

    ----------------------------------------------------------------------------
    -- Memory Process
    ----------------------------------------------------------------------------
    reg_proc: process(clk, areset_n)
    begin
        if areset_n = '0' then
            state_q <= IDLE;
        elsif rising_edge(clk) then
            state_q <= state_d;
        end if;
    end process reg_proc;

end behavioural;
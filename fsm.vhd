library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity SRAM_Swiper_FSM is
    port (
        -- Clock and Reset
        clk             : in  std_logic;
        areset_n        : in  std_logic;

        -- Interfaccia dai Registri AXI (Input)
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
        sram_we         : out std_logic_vector(3 downto 0);
        sram_en         : out std_logic
    );
end SRAM_Swiper_FSM;


architecture behavioural of SRAM_Swiper_FSM is

    component counter is
        generic (
            DATA_WIDTH : integer := 32
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
            DATA_WIDTH : integer := 32; -- Allineato a 32 bit
            RESET_VAL  : STD_LOGIC_VECTOR(31 downto 0) := (others => '0')
        );
        port (
            clk      : in  STD_LOGIC;
            areset_n : in  STD_LOGIC;
            d        : in  STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0);
            q        : out STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0)
        );
    end component;

    -- Tipi di Stato della FSM Estesa
    type state_t is (
        IDLE,
        -- Ramo Preload
        PRELOAD_WRITE,
        PRELOAD_UPDATE,
        PRELOAD_FINISH,
        -- Ramo Swipe
        SWIPE_INIT,
        SWIPE_READ,
        SWIPE_WRITE,
        SWIPE_UPDATE,
        SWIPE_FINISH
    );

    -- State register
    signal state_q, state_d: state_t;

    -- Datapath Counter & Register Signals
    signal sig_cnt_q        : std_logic_vector(31 downto 0) := (others => '0');
    signal sig_cnt_en       : std_logic;
    signal sig_cnt_clear    : std_logic;
    signal sig_cnt_load     : std_logic;
    signal sig_mod_data_in  : std_logic_vector(31 downto 0);
    signal sig_mod_data_out : std_logic_vector(31 downto 0);

begin

    -- Istanza Contatore Indirizzi
    i_address_counter: counter
        generic map (
            DATA_WIDTH => 32
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

    -- Istanza Registro Appoggio Dati (Swipe)
    i_mod_register: register_flip_flop_d_beh
        generic map (
            DATA_WIDTH => 32,
            RESET_VAL  => (others => '0')
        )
        port map (
            clk      => clk,
            areset_n => areset_n,
            d        => sig_mod_data_in,
            q        => sig_mod_data_out
        );

    ----------------------------------------------------------------------------
    -- MOORE OUTPUTS: DATAPATH & CONTROL SIGNALS
    ----------------------------------------------------------------------------
    
    -- Gestione Indirizzi e Dati Verso SRAM
    sram_addr  <= sig_cnt_q;
    sram_wdata <= sig_cnt_q when (state_q = PRELOAD_WRITE) else sig_mod_data_out;
    
    -- In SWIPE_READ sommiamo 1 al dato letto, altrimenti il registro conserva il suo valore
    sig_mod_data_in <= std_logic_vector(unsigned(sram_rdata) + 1) when (state_q = SWIPE_READ) else 
                       sig_mod_data_out;

    -- Enable della memoria: attivo in scrittura Preload, e in lettura/scrittura Swipe
    sram_en <= '1' when (state_q = PRELOAD_WRITE or state_q = SWIPE_READ or state_q = SWIPE_WRITE) else '0';
    
    -- Write Enable: attivo solo quando scriviamo
    sram_we <= "1111" when (state_q = PRELOAD_WRITE or state_q = SWIPE_WRITE) else "0000";

    -- Segnali Verso l'esterno (AXI)
    preload_done <= '1' when state_q = PRELOAD_FINISH else '0';
    swipe_done   <= '1' when state_q = SWIPE_FINISH   else '0';

    -- Controllo Contatore
    sig_cnt_clear <= '1' when state_q = IDLE else '0';
    sig_cnt_load  <= '1' when state_q = SWIPE_INIT else '0';
    sig_cnt_en    <= '1' when (state_q = PRELOAD_UPDATE or state_q = SWIPE_UPDATE) else '0';


    ----------------------------------------------------------------------------
    -- NEXT STATE LOGIC
    ----------------------------------------------------------------------------
    -- Aggiunti alla sensitivity list tutti i segnali usati per le decisioni
    next_state_proc: process(state_q, preload_start, swipe_start, num_w_in, src_addr_in, sig_cnt_q)
    begin
        state_d <= state_q; -- Default: rimani nello stato attuale

        case state_q is
            when IDLE =>
                if preload_start = '1' then
                    state_d <= PRELOAD_WRITE;
                elsif swipe_start = '1' then
                    state_d <= SWIPE_INIT;
                end if;

            -- ==========================
            -- RAMO 1: PRELOAD
            -- ==========================
            when PRELOAD_WRITE =>
                state_d <= PRELOAD_UPDATE;
            
            when PRELOAD_UPDATE =>
                -- Controlla se abbiamo scritto 'num_w_in' parole partendo da 0
                if unsigned(sig_cnt_q) = (unsigned(num_w_in) - 1) then 
                    state_d <= PRELOAD_FINISH;
                else
                    state_d <= PRELOAD_WRITE;
                end if;

            when PRELOAD_FINISH =>
                if preload_start = '0' then
                    state_d <= IDLE;
                end if;
            
            -- ==========================
            -- RAMO 2: SWIPE
            -- ==========================
            when SWIPE_INIT =>
                -- Il contatore carica src_addr_in, andiamo a leggere
                state_d <= SWIPE_READ;
                
            when SWIPE_READ =>
                -- Lettura avvenuta, il dato entra nel registro. Andiamo a scrivere.
                state_d <= SWIPE_WRITE;
                
            when SWIPE_WRITE =>
                -- Scrittura avvenuta. Aggiorniamo indirizzo.
                state_d <= SWIPE_UPDATE;
                
            when SWIPE_UPDATE =>
                -- Controlla se siamo arrivati all'indirizzo finale (Partenza + Lunghezza - 1)
                if unsigned(sig_cnt_q) = (unsigned(src_addr_in) + unsigned(num_w_in) - 1) then
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
    -- STATE REGISTER UPDATE
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
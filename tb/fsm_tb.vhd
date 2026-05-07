library ieee;
use ieee.STD_LOGIC_1164.all;
use ieee.numeric_std.all; -- Aggiunto per poter usare to_unsigned()

entity fsm_tb is
end fsm_tb;

architecture behavioural of fsm_tb is

    -- 1. DUT connections (Inizializzati a 0 per evitare stati 'U' nel simulatore)
    signal clk             : std_logic := '0';
    signal areset_n        : std_logic := '0';
    signal src_addr_in     : std_logic_vector(31 downto 0) := (others => '0');
    signal num_w_in        : std_logic_vector(31 downto 0) := (others => '0');
    signal preload_start   : std_logic := '0';
    signal swipe_start     : std_logic := '0';
    signal sram_rdata      : std_logic_vector(31 downto 0) := (others => '0');

    -- Output dello slave (Non si inizializzano perché li pilota la FSM)
    signal preload_done    : std_logic;
    signal swipe_done      : std_logic;
    signal sram_addr       : std_logic_vector(31 downto 0);
    signal sram_wdata      : std_logic_vector(31 downto 0);
    signal sram_we         : std_logic_vector(3 downto 0);
    signal sram_en         : std_logic;

begin

    -- 2. Instantiate DUT
    -- (Nota: Assicurati che l'entity name qui combaci con il tuo file FSM. 
    -- Se l'hai chiamato SRAM_Swiper_FSM, cambia work.fsm in work.SRAM_Swiper_FSM)
    DUT: entity work.SRAM_Swiper_FSM 
        port map (
            clk                   =>   clk,
            areset_n              =>   areset_n,
            src_addr_in           =>   src_addr_in,     
            num_w_in              =>   num_w_in,        
            preload_start         =>   preload_start,   
            swipe_start           =>   swipe_start,     
        
            preload_done          =>   preload_done,    
            swipe_done            =>   swipe_done,      
        
            sram_addr             =>   sram_addr,       
            sram_wdata            =>   sram_wdata,      
            sram_rdata            =>   sram_rdata,      
            sram_we               =>   sram_we,         
            sram_en               =>   sram_en         
        );

    -- 3. Generazione del Clock (Periodo 20 ns -> 50 MHz)
    clk <= not clk after 10 ns;

    -- 4. Stimulus process
    stim_proc: process
    begin
        ---------------------------------------
        -- INIZIALIZZAZIONE E RESET
        ---------------------------------------
        report "[TB] Inizio Simulazione: Esecuzione Reset Hardware";
        areset_n <= '0';
        wait for 45 ns; -- Aspettiamo un paio di cicli di clock asincroni
        areset_n <= '1';
        wait for 20 ns; 

        ---------------------------------------
        -- TEST CASE 1: Esecuzione PRELOAD
        ---------------------------------------
        report "[TB] Test Case 1: Avvio operazione di PRELOAD";
        
        -- Impostiamo il numero di parole da scrivere. 
        -- Mettiamo 4 parole invece di 256 così la simulazione è veloce e leggibile.
        num_w_in <= std_logic_vector(to_unsigned(4, 32)); 
        wait until rising_edge(clk);
        
        -- Il processore alza il flag di start
        preload_start <= '1';
        
        -- Aspettiamo un ciclo di clock e vediamo che la FSM inizia a lavorare, 
        -- poi il processore può anche mantenere il segnale alto (simulando un bus AXI reale)
        wait for 40 ns; 

        -- Ora ci mettiamo in attesa "intelligente": blocchiamo il testbench 
        -- finché la FSM non alza il flag di done.
        wait until preload_done = '1';
        report "[TB] Preload completato dalla FSM!";

        -- Il processore legge il done e riabbassa lo start per far tornare la FSM in IDLE
        wait until rising_edge(clk);
        preload_start <= '0';

        -- Aspettiamo qualche ciclo a vuoto per verificare che la macchina torni a riposo 
        -- (sram_en e sram_we devono tornare a zero)
        wait for 60 ns;


        ---------------------------------------
        -- TEST CASE 2: Esecuzione SWIPE (Placeholder per il futuro)
        ---------------------------------------
        -- report "[TB] Test Case 2: Avvio operazione di SWIPE";
        -- src_addr_in <= std_logic_vector(to_unsigned(0, 32));
        -- num_w_in <= std_logic_vector(to_unsigned(4, 32));
        -- wait until rising_edge(clk);
        -- swipe_start <= '1';
        -- wait until swipe_done = '1';
        -- wait until rising_edge(clk);
        -- swipe_start <= '0';
        -- wait for 60 ns;

        ----------------------
        -- End of simulation -
        ----------------------
        report "[TB] Simulation Finished Successfully";
        std.env.finish;
    end process;

end behavioural;
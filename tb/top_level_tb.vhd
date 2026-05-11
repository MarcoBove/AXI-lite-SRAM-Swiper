library ieee;
use ieee.STD_LOGIC_1164.all;
use ieee.numeric_std.all; 

entity top_level_tb is
end top_level_tb;

architecture behavioural of top_level_tb is

    -- 1. DUT connections 
    signal clk             : std_logic := '0';
    signal areset_n        : std_logic := '0';
    signal src_addr_in     : std_logic_vector(31 downto 0) := (others => '0');
    signal num_w_in        : std_logic_vector(31 downto 0) := (others => '0');
    signal preload_start   : std_logic := '0';
    signal swipe_start     : std_logic := '0';

    -- Output del Top Level
    signal preload_done    : std_logic;
    signal swipe_done      : std_logic;

begin

    -- 2. Instantiate DUT
    DUT: entity work.top_level
        port map (
            clk                   =>   clk,
            areset_n              =>   areset_n,
            src_addr_in           =>   src_addr_in,     
            num_w_in              =>   num_w_in,        
            preload_start         =>   preload_start,   
            swipe_start           =>   swipe_start,     
            preload_done          =>   preload_done,    
            swipe_done            =>   swipe_done      
        );

    -- 3. Generazione del Clock 
    clk <= not clk after 10 ns;

    -- 4. Stimulus process
    stim_proc: process
    begin
        ---------------------------------------
        -- INIZIALIZZAZIONE E RESET
        ---------------------------------------
        report "[TB] Inizio Simulazione: Esecuzione Reset Hardware";
        areset_n <= '0';
        wait for 45 ns; -- Wait
        areset_n <= '1';
        wait for 20 ns; 

        ---------------------------------------
        -- TEST CASE 1: Esecuzione PRELOAD
        ---------------------------------------
        report "[TB] Test Case 1: Avvio operazione di PRELOAD";
        
        num_w_in <= std_logic_vector(to_unsigned(4, 32)); 
        wait until rising_edge(clk);
        
        -- Il processore alza il flag di start
        preload_start <= '1';
        
        wait for 40 ns; 

        wait until preload_done = '1';
        report "[TB] Preload completato dalla FSM!";

        
        wait until rising_edge(clk);
        preload_start <= '0';

        wait for 60 ns;

        ----------------------
        -- End of simulation -
        ----------------------
        report "[TB] Simulation Finished Successfully";
        std.env.finish; 
    end process;

end behavioural;
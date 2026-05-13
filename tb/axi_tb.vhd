library ieee;
use ieee.STD_LOGIC_1164.all;
use ieee.numeric_std.all; 

entity axi_tb is -- CORRETTO: Aggiunto 'is'
end entity;

architecture behavioural of axi_tb is

    -- =========================================================================
    -- DICHIARAZIONE DEI SEGNALI DEL BUS AXI (Inizializzati per il Testbench)
    -- =========================================================================
    signal clk             : std_logic := '0';
    signal areset_n        : std_logic := '0';

    -- Canale AW (Scrittura Indirizzo)
    signal s00_axi_awaddr  : std_logic_vector(4 downto 0) := (others => '0'); -- 5 BIT!
    signal s00_axi_awvalid : std_logic := '0';
    signal s00_axi_awready : std_logic;

    -- Canale W (Scrittura Dati)
    signal s00_axi_wdata   : std_logic_vector(31 downto 0) := (others => '0');
    signal s00_axi_wstrb   : std_logic_vector(3 downto 0) := (others => '0');
    signal s00_axi_wvalid  : std_logic := '0';
    signal s00_axi_wready  : std_logic;

    -- Canale B (Risposta Scrittura)
    signal s00_axi_bresp   : std_logic_vector(1 downto 0);
    signal s00_axi_bvalid  : std_logic;
    signal s00_axi_bready  : std_logic := '0';

    -- Canale AR (Lettura Indirizzo)
    signal s00_axi_araddr  : std_logic_vector(4 downto 0) := (others => '0'); -- 5 BIT!
    signal s00_axi_arvalid : std_logic := '0';
    signal s00_axi_arready : std_logic;

    -- Canale R (Lettura Dati)
    signal s00_axi_rdata   : std_logic_vector(31 downto 0);
    signal s00_axi_rresp   : std_logic_vector(1 downto 0);
    signal s00_axi_rvalid  : std_logic;
    signal s00_axi_rready  : std_logic := '0';

begin

    -- Istanziazione del Guscio Esterno AXI
    DUT: entity work.AXI_Lite_SRAM_Swiper
        port map (
            s00_axi_aclk    => clk,
            s00_axi_aresetn => areset_n,
            
            s00_axi_awaddr  => s00_axi_awaddr,
            s00_axi_awprot  => "000", 
            s00_axi_awvalid => s00_axi_awvalid,
            s00_axi_awready => s00_axi_awready,
            
            s00_axi_wdata   => s00_axi_wdata,
            s00_axi_wstrb   => s00_axi_wstrb,
            s00_axi_wvalid  => s00_axi_wvalid,
            s00_axi_wready  => s00_axi_wready,
            
            s00_axi_bresp   => s00_axi_bresp,
            s00_axi_bvalid  => s00_axi_bvalid,
            s00_axi_bready  => s00_axi_bready,
            
            s00_axi_araddr  => s00_axi_araddr,
            s00_axi_arprot  => "000",
            s00_axi_arvalid => s00_axi_arvalid,
            s00_axi_arready => s00_axi_arready,
            
            s00_axi_rdata   => s00_axi_rdata,
            s00_axi_rresp   => s00_axi_rresp,
            s00_axi_rvalid  => s00_axi_rvalid,
            s00_axi_rready  => s00_axi_rready
        );

    -- Generazione del Clock (50 MHz)
    clk <= not clk after 10 ns;
    
    stim_proc: process
        -----------------------------------------------------------------------
        -- PROCEDURA: SCRITTURA AXI LITE
        -----------------------------------------------------------------------
        procedure axi_write (
            constant addr_in : in std_logic_vector(31 downto 0);
            constant data_in : in std_logic_vector(31 downto 0)
        ) is
        begin
            -- 1. Canale AW (Prendiamo solo i 5 bit bassi per evitare errori di range!)
            s00_axi_awaddr <= addr_in(4 downto 0);
            s00_axi_awvalid <= '1';
            wait until rising_edge(clk) and s00_axi_awready = '1';
            s00_axi_awvalid <= '0';

            -- 2. Canale W 
            s00_axi_wdata <= data_in;
            s00_axi_wstrb <= "1111"; 
            s00_axi_wvalid <= '1';
            wait until rising_edge(clk) and s00_axi_wready = '1';
            s00_axi_wvalid <= '0';

            -- 3. Canale B 
            s00_axi_bready <= '1';
            wait until rising_edge(clk) and s00_axi_bvalid = '1';
            s00_axi_bready <= '0';
            
            wait until rising_edge(clk);
        end procedure;

        -----------------------------------------------------------------------
        -- PROCEDURA: LETTURA AXI LITE
        -----------------------------------------------------------------------
        procedure axi_read (
            constant addr_in : in std_logic_vector(31 downto 0);
            variable data_out : out std_logic_vector(31 downto 0)
        ) is
        begin
            -- 1. Canale AR (Prendiamo solo i 5 bit bassi)
            s00_axi_araddr <= addr_in(4 downto 0);
            s00_axi_arvalid <= '1';
            wait until rising_edge(clk) and s00_axi_arready = '1';
            s00_axi_arvalid <= '0';

            -- 2. Canale R 
            s00_axi_rready <= '1';
            wait until rising_edge(clk) and s00_axi_rvalid = '1';
            data_out := s00_axi_rdata; 
            s00_axi_rready <= '0';
            
            wait until rising_edge(clk);
        end procedure;

        variable read_data_var : std_logic_vector(31 downto 0);

    begin  
        
        report "[TB] Inizio Simulazione: Reset Hardware";
        areset_n <= '0';
        wait for 45 ns;
        areset_n <= '1';
        wait for 20 ns; 

        report "[TB] Inizio Test Preload via AXI...";
        
        -- 1. Impostiamo NUM_W = 4 nel Registro 3 (Indirizzo 0x0C)
        axi_write(x"0000000C", x"00000004");
        
        -- 2. Diamo lo START alzando il bit 0 del Registro 1 (Indirizzo 0x04)
        axi_write(x"00000004", x"00000001");
        
        -- 3. Polling sul Registro 2 (Indirizzo 0x08)
        loop
            axi_read(x"00000008", read_data_var);
            -- Se il bit 0 del dato letto è '1', usciamo dal loop!
            exit when read_data_var(0) = '1';
        end loop;
        
        report "[TB] Preload completato letto via AXI!";

        -- 4. Abbassiamo lo START
        axi_write(x"00000004", x"00000000");
        
        wait for 60 ns;

        report "[TB] Simulazione finita con successo.";
        --wait;
        std.env.finish; 
    end process;

end behavioural;
library ieee;
use ieee.STD_LOGIC_1164.all;
use ieee.numeric_std.all; 

-- =========================================================================
-- Entity: axi_tb
-- Description: Self-Checking Testbench for the AXI_Lite_SRAM_Swiper.
--              Includes assert statements for AXI read-back verification
--              and timeout watchdogs for FSM polling operations.
-- =========================================================================
entity axi_tb is 
end entity;

architecture behavioural of axi_tb is

    -- =========================================================================
    -- AXI BUS SIGNALS DECLARATION (Initialized for the Testbench)
    -- =========================================================================
    signal clk             : std_logic := '0';
    signal areset_n        : std_logic := '0';

    -- AW Channel (Write Address)
    signal s00_axi_awaddr  : std_logic_vector(4 downto 0) := (others => '0');
    signal s00_axi_awvalid : std_logic := '0';
    signal s00_axi_awready : std_logic;

    -- W Channel (Write Data)
    signal s00_axi_wdata   : std_logic_vector(31 downto 0) := (others => '0');
    signal s00_axi_wstrb   : std_logic_vector(3 downto 0) := (others => '0');
    signal s00_axi_wvalid  : std_logic := '0';
    signal s00_axi_wready  : std_logic;

    -- B Channel (Write Response)
    signal s00_axi_bresp   : std_logic_vector(1 downto 0);
    signal s00_axi_bvalid  : std_logic;
    signal s00_axi_bready  : std_logic := '0';

    -- AR Channel (Read Address)
    signal s00_axi_araddr  : std_logic_vector(4 downto 0) := (others => '0');
    signal s00_axi_arvalid : std_logic := '0';
    signal s00_axi_arready : std_logic;

    -- R Channel (Read Data)
    signal s00_axi_rdata   : std_logic_vector(31 downto 0);
    signal s00_axi_rresp   : std_logic_vector(1 downto 0);
    signal s00_axi_rvalid  : std_logic;
    signal s00_axi_rready  : std_logic := '0';

begin

    -- =========================================================================
    -- DUT Instantiation (Device Under Test)
    -- =========================================================================
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

    -- Clock Generation (50 MHz)
    clk <= not clk after 10 ns;
    
    -- =========================================================================
    -- Main Stimulus Process
    -- =========================================================================
    stim_proc: process
        -----------------------------------------------------------------------
        -- PROCEDURE: AXI LITE WRITE TRANSACTION
        -----------------------------------------------------------------------
        procedure axi_write (
            constant addr_in : in std_logic_vector(31 downto 0);
            constant data_in : in std_logic_vector(31 downto 0)
        ) is
        begin
            -- 1. AW Channel (Address Write)
            s00_axi_awaddr <= addr_in(4 downto 0);
            s00_axi_awvalid <= '1';
            wait until rising_edge(clk) and s00_axi_awready = '1';
            s00_axi_awvalid <= '0';

            -- 2. W Channel (Data Write)
            s00_axi_wdata <= data_in;
            s00_axi_wstrb <= "1111"; 
            s00_axi_wvalid <= '1';
            wait until rising_edge(clk) and s00_axi_wready = '1';
            s00_axi_wvalid <= '0';

            -- 3. B Channel (Write Response)
            s00_axi_bready <= '1';
            wait until rising_edge(clk) and s00_axi_bvalid = '1';
            s00_axi_bready <= '0';
            
            wait until rising_edge(clk);
        end procedure;

        -----------------------------------------------------------------------
        -- PROCEDURE: AXI LITE READ TRANSACTION
        -----------------------------------------------------------------------
        procedure axi_read (
            constant addr_in : in std_logic_vector(31 downto 0);
            variable data_out : out std_logic_vector(31 downto 0)
        ) is
        begin
            -- 1. AR Channel (Address Read)
            s00_axi_araddr <= addr_in(4 downto 0);
            s00_axi_arvalid <= '1';
            wait until rising_edge(clk) and s00_axi_arready = '1';
            s00_axi_arvalid <= '0';

            -- 2. R Channel (Data Read)
            s00_axi_rready <= '1';
            wait until rising_edge(clk) and s00_axi_rvalid = '1';
            data_out := s00_axi_rdata; 
            s00_axi_rready <= '0';
            
            wait until rising_edge(clk);
        end procedure;

        -- Variables for testing and polling
        variable read_data_var : std_logic_vector(31 downto 0);
        variable timeout_cnt   : integer := 0;
        constant MAX_TIMEOUT   : integer := 2000; -- Max clock cycles to wait

    begin  
        
        report "[TB] Starting Simulation: Hardware Reset";
        areset_n <= '0';
        wait for 45 ns;
        areset_n <= '1';
        wait for 20 ns; 

        -- =====================================================================
        -- TEST 1: PRELOAD OPERATION (256 Words)
        -- =====================================================================
        report "[TB] Starting Preload Test via AXI...";
        
        -- Write NUM_W = 256 (0x00000100) to Register 3 (Address 0x0C)
        axi_write(x"0000000C", x"00000100");
        
        -- Read-back ASSERTION: Ensure AXI write was successful
        axi_read(x"0000000C", read_data_var);
        assert read_data_var = x"00000100" 
            report "[ASSERT FAILED] Register 3 (NUM_W) was not written correctly!" 
            severity failure;
        
        -- Trigger START by setting bit 0 of Register 1 (Address 0x04)
        axi_write(x"00000004", x"00000001");
        
        -- Polling on Register 2 (Address 0x08) to wait for PRELOAD_DONE
        timeout_cnt := 0;
        loop
            axi_read(x"00000008", read_data_var);
            timeout_cnt := timeout_cnt + 1;
            -- Exit condition: FSM finished OR timeout reached
            exit when read_data_var(0) = '1' or timeout_cnt > MAX_TIMEOUT;
        end loop;
        
        -- Timeout ASSERTION: Check if we exited the loop because of a timeout
        assert read_data_var(0) = '1' 
            report "[ASSERT FAILED] TIMEOUT! Preload operation took too long or FSM got stuck." 
            severity failure;
            
        report "[TB] Preload completed successfully!";

        -- Clear START to return FSM to IDLE
        axi_write(x"00000004", x"00000000");
        wait for 60 ns;


        -- =====================================================================
        -- TEST 2: SWIPE OPERATION (256 Words)
        -- =====================================================================
        report "[TB] Starting Swipe Test via AXI...";
        
        -- Write starting address SRC_ADDR = 0 to Register 0 (Address 0x00)
        axi_write(x"00000000", x"00000000");
        
        -- Read-back ASSERTION for SRC_ADDR
        axi_read(x"00000000", read_data_var);
        assert read_data_var = x"00000000" 
            report "[ASSERT FAILED] Register 0 (SRC_ADDR) was not written correctly!" 
            severity failure;
        
        -- Write NUM_W = 256 (0x00000100) to Register 3 (Address 0x0C)
        axi_write(x"0000000C", x"00000100");
        
        -- Trigger START by setting bit 0 of Register 4 (Address 0x10)
        axi_write(x"00000010", x"00000001");
        
        -- Polling on Register 5 (Address 0x14) to wait for SWIPE_DONE
        timeout_cnt := 0;
        loop
            axi_read(x"00000014", read_data_var);
            timeout_cnt := timeout_cnt + 1;
            exit when read_data_var(0) = '1' or timeout_cnt > MAX_TIMEOUT;
        end loop;
        
        -- Timeout ASSERTION for Swipe
        assert read_data_var(0) = '1' 
            report "[ASSERT FAILED] TIMEOUT! Swipe operation took too long or FSM got stuck." 
            severity failure;
            
        report "[TB] Swipe completed successfully!";

        -- Clear START to return FSM to IDLE
        axi_write(x"00000010", x"00000000");
        wait for 60 ns;

        -- =====================================================================
        -- END OF SIMULATION
        -- =====================================================================
        report "[TB] All assertions passed. Simulation finished successfully.";
        std.env.finish; 
    end process;

end behavioural;
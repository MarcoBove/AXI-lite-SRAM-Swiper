library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all; 

entity top_level is
    generic (
            RESET_VAL  : STD_LOGIC := '0';
            NUM_WORDS  : integer := 256;
            DATA_WIDTH : integer := 32
        );
    port (
        -- Clock and Reset
        clk             : in  std_logic;
        areset_n        : in  std_logic;

        -- Interfaccia dai Registri AXI (Input)
        src_addr_in     : in  std_logic_vector(31 downto 0);
        num_w_in        : in  std_logic_vector(31 downto 0);
        preload_start   : in  std_logic;
        swipe_start     : in  std_logic;

        -- Interfaccia verso i Registri AXI (Output di Stato)
        preload_done    : out std_logic;
        swipe_done      : out std_logic 
    );
end top_level;

architecture behavioural of top_level  is

    component sram is
        generic (
            RESET_VAL  : STD_LOGIC := '0';
            NUM_WORDS  : integer := 256;
            DATA_WIDTH : integer := 32
        );
        port (
            clk      : in  STD_LOGIC;
            areset_n : in  STD_LOGIC;
            cs       : in  STD_LOGIC;
            addr     : in  STD_LOGIC_VECTOR(integer(ceil(log2(real(NUM_WORDS))))-1 downto 0);
            we       : in  STD_LOGIC_VECTOR((DATA_WIDTH/8)-1 downto 0);
            wdata    : in  STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0);
            rdata    : out STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0)
        );
    end component;

    component SRAM_Swiper_FSM is
        port (
            clk             : in  std_logic;
            areset_n        : in  std_logic;
            src_addr_in     : in  std_logic_vector(31 downto 0);
            num_w_in        : in  std_logic_vector(31 downto 0);
            preload_start   : in  std_logic;
            swipe_start     : in  std_logic;
            preload_done    : out std_logic;
            swipe_done      : out std_logic;
            
            sram_addr       : out std_logic_vector(31 downto 0);
            sram_wdata      : out std_logic_vector(31 downto 0);
            sram_rdata      : in  std_logic_vector(31 downto 0);
            sram_we         : out std_logic_vector(3 downto 0);
            sram_en         : out std_logic
        );
    end component;

    -- Fili Interni (Datapath)
    signal sig_addr  : std_logic_vector(31 downto 0);
    signal sig_wdata : std_logic_vector(31 downto 0);
    signal sig_rdata : std_logic_vector(31 downto 0);
    signal sig_we    : std_logic_vector(3 downto 0);
    signal sig_en    : std_logic;

begin
    -- Istanza FSM
    i_fsm: SRAM_Swiper_FSM
        port map (
            clk             => clk,
            areset_n        => areset_n,
            src_addr_in     => src_addr_in, 
            num_w_in        => num_w_in,
            preload_start   => preload_start,
            swipe_start     => swipe_start,
            preload_done    => preload_done,
            swipe_done      => swipe_done,
            
            sram_addr       => sig_addr,
            sram_wdata      => sig_wdata,
            sram_rdata      => sig_rdata,
            sram_we         => sig_we,
            sram_en         => sig_en         
        );

    -- Istanza SRAM
    i_sram: sram
        generic map(
            RESET_VAL  => RESET_VAL,
            NUM_WORDS  => NUM_WORDS,
            DATA_WIDTH => DATA_WIDTH
        )
        port map (
            clk        => clk,
            areset_n   => areset_n,
            cs         => sig_en, 
            
            -- Troncamento a dimensione esatta per l'indirizzo
            addr       => sig_addr(integer(ceil(log2(real(NUM_WORDS))))-1 downto 0),
            
            wdata      => sig_wdata,
            rdata      => sig_rdata,
            we         => sig_we         
        );

end behavioural;
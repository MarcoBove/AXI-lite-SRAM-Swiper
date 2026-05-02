library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity SRAM_Swiper_FSM is
    port (
        -- Clock e Reset
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

architecture rtl of SRAM_Swiper_FSM is

    -- Definizione degli stati (Aggiungi qui i tuoi stati)
    type state_type is (IDLE, PRELOAD_OP, SWIPE_READ, SWIPE_MODIFY, SWIPE_WRITE, DONE);
    signal current_state, next_state : state_type;

    -- Segnali interni (Contatori, registri temporanei per il dato letto, ecc.)
    -- Esempio: signal addr_counter : unsigned(31 downto 0);

begin

    -----------------------------------------------------
    -- Processo 1: Registro dello Stato (Sincrono)
    -----------------------------------------------------
    state_reg: process(clk, areset_n)
    begin
        if areset_n = '0' then
            current_state <= IDLE;
        elsif rising_edge(clk) then
            current_state <= next_state;
        end if;
    end process;

    -----------------------------------------------------
    -- Processo 2: Logica dello Stato Prossimo (Combinatorio)
    -----------------------------------------------------
    -- Qui decidi come passare da uno stato all'altro
    next_state_logic: process(current_state, preload_start, swipe_start)
    begin
        next_state <= current_state; -- Default: rimani nello stato attuale

        case current_state is
            when IDLE =>
                if preload_start = '1' then
                    next_state <= PRELOAD_OP;
                elsif swipe_start = '1' then
                    next_state <= SWIPE_READ;
                end if;

            when PRELOAD_OP =>
                -- Scrivi qui la logica per finire il preload
            
            when others =>
                next_state <= IDLE;
        end case;
    end process;

    -----------------------------------------------------
    -- Processo 3: Logica delle Uscite
    -----------------------------------------------------
    -- Qui piloti sram_addr, sram_we, preload_done, ecc.
    output_logic: process(current_state)
    begin
        -- Valori di default per evitare latch
        sram_en    <= '0';
        sram_we    <= (others => '0');
        preload_done <= '0';
        swipe_done   <= '0';

        case current_state is
            when PRELOAD_OP =>
                sram_en <= '1';
                -- sram_we <= "1111"; 
                -- ecc...
            when others =>
                null;
        end case;
    end process;

end rtl;
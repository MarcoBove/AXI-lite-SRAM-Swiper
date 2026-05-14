library ieee;
use ieee.STD_LOGIC_1164.all;
use ieee.numeric_std.all;

entity counter is
    generic (
        DATA_WIDTH : integer := 4 
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
end counter; 

architecture behavioural of counter is
    signal count_val : unsigned(DATA_WIDTH-1 downto 0);
begin
    q <= STD_LOGIC_VECTOR(count_val);

    count_up: process (clk, areset_n)
    begin
        if areset_n = '0' then
            count_val <= (others => '0');
        elsif rising_edge(clk) then
            if clear = '1' then
                count_val <= (others => '0');
            elsif load = '1' then
                count_val <= unsigned(d_in); -- Carica il valore di partenza!
            elsif en = '1' then
                count_val <= count_val + 1;
            end if;

        end if;
    end process count_up;
end behavioural;
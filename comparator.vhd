library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Comparator checks that the counter has reached the number of words 

entity comparator is
    generic(
        DATA_WIDTH : integer := 32 
    );
    port (
        current_cnt : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        start_addr  : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        num_words   : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        is_done     : out std_logic
    );
end comparator;

architecture dataflow of comparator is
begin
    is_done <= '1' when unsigned(current_cnt) = (unsigned(start_addr) + unsigned(num_words) - 1) else '0';
end architecture;
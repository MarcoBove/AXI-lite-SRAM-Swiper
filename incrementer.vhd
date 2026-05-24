library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- The incrementer adds +1 to the input data.

entity incrementer is
     generic(
        DATA_WIDTH : integer := 32 
    );
    port (
        d_in  : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        d_out : out std_logic_vector(DATA_WIDTH-1 downto 0)
    );
end incrementer;

architecture dataflow of incrementer is
begin
    d_out <= std_logic_vector(unsigned(d_in) + 1);
end dataflow;
library ieee;
use ieee.STD_LOGIC_1164.all; -- Standard logic library
use ieee.numeric_std.all;    -- Library for arithmetic operations on unsigned/signed types

-- Generic N-bit counter entity
entity counter is
    generic (
        DATA_WIDTH : integer := 32 -- Width of the counter in bits 
    );
    port (
        clk      : in  STD_LOGIC;                                -- System clock input
        areset_n : in  STD_LOGIC;                                -- Active-low asynchronous reset
        clear    : in  STD_LOGIC;                                -- Active-high synchronous clear
        en       : in  STD_LOGIC;                                -- Count enable signal
        load     : in  STD_LOGIC;                                -- Parallel load enable signal
        d_in     : in  STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0);  -- Parallel data input for loading

        q        : out STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0)   -- Counter output value
    );
end counter; 

-- Behavioral architecture defining the counter's logic
architecture behavioural of counter is
    -- Internal signal used to perform arithmetic additions
    signal count_val : unsigned(DATA_WIDTH-1 downto 0);
begin
    -- Continuously assign the internal unsigned signal to the output port (type casting)
    q <= STD_LOGIC_VECTOR(count_val);

    -- Process that handles the counting logic, sensitive to clock and async reset
    count_up: process (clk, areset_n)
    begin
        -- Asynchronous reset: immediately resets the counter to 0 if areset_n is low
        if areset_n = '0' then
            count_val <= (others => '0');
            
        -- Synchronous operations: triggered on the rising edge of the clock
        elsif rising_edge(clk) then
            -- Highest priority: synchronous clear
            if clear = '1' then
                count_val <= (others => '0');
                
            -- Second priority: load external data into the counter
            elsif load = '1' then
                count_val <= unsigned(d_in); 
                
            -- Third priority: increment the counter by 1 if enabled
            elsif en = '1' then
                count_val <= count_val + 1;
            end if;

        end if;
    end process count_up;
end behavioural;
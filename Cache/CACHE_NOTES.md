# L1 cache clock-speed edits

The optimized L1 cache is enabled by default through `DataPath.USE_L1_CACHE=1`.
Set that parameter to `0` to synthesize the direct-`DataMem` bypass baseline.

## Notes

1. 
   - `ADDR_WIDTH=12` because `DataMem` implements 1024 32-bit words.
   - With 16 direct-mapped lines, the address is now a 6-bit tag, 4-bit index, and 2-bit byte offset.

2. 
   - `ENABLE_MSI=0` for the current single-core configuration.
   - MSI RTL is preserved under `gen_msi`, but the single-core synthesized hit
     check uses only valid and the 6-bit tag.

3. 
   - Replaced the asynchronous CPU response/stall interface with registered
     request and response channels.
   - The cache now moves through `CACHE_IDLE`, `CACHE_LOOKUP`, and `CACHE_RESPONSE`
   - Tag comparison drives cache-local response registers instead of the clock
     enables for the entire CPU pipeline.

4. 
   - EX/MEM holds a load/store request until `cacheResponseValid_MEM` is set.
   - `cacheStall_MEM` now depends only on whether a request exists and whether
     the registered response is valid.
   - The direct-`DataMem` bypass implementation remains available.

5. 
  - Read hit: Cache word becomes the response
  - Read miss: Cache word comes from DataMem and installed in cache for future access
  - Every write stores to backing memory 
  - Write hit: Cache updates cache line and DataMem
  - Write miss: Cache uses write allocaiton, updates tag, cache, datamem


## Expected tradeoff

The registered blocking cache adds cycles to each memory transaction, but it is intended to raise maximum clock frequency.
This can support a higher hardware clock frequency and gives the cache a clean interface that could later support a slower memory.

`execution time = instruction count * CPI * clock period`

The Verilator CPU benchmark produces CPI and instruction count
Clock period on Vivado timing Analysis

Why register the transaction?
Previous path 
 → cache tags
 → tag comparison
 → hit/miss logic
 → cache stall
 → pipeline clock enables

After
Clock 1: save request
clock 2: perform lookup and save response
Clock 3: pipeline consumes response

Index: “Which physical cache line should I inspect?”
Valid bit: “Does this line contain meaningful data?”
Tag: “Which backing-memory address does this data belong to?”
Data: “What is the stored 32-bit value?”
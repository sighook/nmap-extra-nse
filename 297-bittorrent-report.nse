local stdnse = require "stdnse"
local table = require "table"
local target = require "target"
local lfs = require "lfs"

local bittorrent = stdnse.silent_require "bittorrent"

description = [[
This script is an adaptation of <bittorent-discovery.nse> and can be used
to retrieve the number of [seeders] and [leeches] for a variable number of
.torrent files. User must specify the root directory then the script will
recursively load and test each .torrent file found.
DHT discovery will not be performed and no target machine will be investigated
for open ports. IPs read from communicated data can be printed on standard
output using the -d debug feature (or -v).
The idea is to have a statistic of data available/requested. A report is 
printed on standard output, a list of files and their values.
Note: HTTP values are guessed and may be incorrect.
]]

--
-- @usage
-- nmap --script bittorrent-report --script-args bittorrent-report.rdir=<directory path>,bittorrent-report.blist=<file path>
--
-- @args bittorrent-report.rdir    string, top directory path          [required]
-- @args bittorrent-report.blist   string, blacklist's filename        [optional]
-- @args bittorrent-report.sort    number, column for sorting output   [to be done]
--
-- @output
-- | bittorrent-report: 
-- |   [c:\_ROOTDIR_\FILENAME_1.torrent]                           seeders[8]    leeches[3]
-- |   [c:\_ROOTDIR_\FILENAME_2.torrent]                           seeders[2]    leeches[2]
-- |   [c:\_ROOTDIR_\_LEVEL_1_\FILENAME_3.torrent]                 seeders[1]    leeches[4]
-- |   [c:\_ROOTDIR_\_LEVEL_1_\FILENAME_4.torrent]                 seeders[0]    leeches[1]
-- |   [c:\_ROOTDIR_\_LEVEL_1_\_LEVEL_1A_\FILENAME_5.torrent]      seeders[4]    leeches[2]
-- |   [c:\_ROOTDIR_\_LEVEL_1_\_LEVEL_1A_\FILENAME_6.torrent]      seeders[2]    leeches[3]
-- |   [c:\_ROOTDIR_\_LEVEL_1_\_LEVEL_1B_\FILENAME_7.torrent]      seeders[1]    leeches[3]
-- |_  [c:\_ROOTDIR_\_LEVEL_1_\_LEVEL_1B_\FILENAME_8.torrent]      <-- Load file failed.
--

author = "Antonio de Curtis"
license = "Same as Nmap--See https://nmap.org/book/man-legal.html"
categories = {"discovery","safe"}


prerule = function()
  if not stdnse.get_script_args(SCRIPT_NAME..".rdir") then
    stdnse.debug3("Skipping '%s' %s, No root directory specified.", SCRIPT_NAME, SCRIPT_TYPE)
    return false
  end
  return true
end

action = function()
  local recurse_dir = stdnse.get_script_args(SCRIPT_NAME..".rdir")
  local bl_filename = stdnse.get_script_args(SCRIPT_NAME..".blist")

  if not recurse_dir then return false end

  local blist_table   = {}
  local results_table = {}
  local DIR_SEP       = lfs.get_path_separator()

  -- load the blacklist if any
  --
  if bl_filename then
    local torr  = bittorrent.Torrent:new()
    blist_table = torr:load_blacklist(bl_filename)
  end

  -- recurse [_top directory_] and execute test
  --
  function browseFolder(root)
    stdnse.debug(0, "Folder [" .. root .. "]")

    for entity in lfs.dir(root) do
      if entity~="." and entity~=".." then
        local fullPath = root..DIR_SEP..entity
        local test_ent = false

        -- since lfs.attributes() is not available we fool the thing
        --
        for testing in lfs.dir(fullPath) do
          test_ent = true
          break
        end

        -- process a file
        --
        if false == test_ent then          
          -- discard spurios file names
          --
          local a, b = string.find(fullPath, ".torrent")  
          if a and b then
            stdnse.debug(0, " File [" .. fullPath .. "]")

            local torrent = bittorrent.Torrent:new()
            local ok, err_text = torrent:load_from_file(fullPath)
        
            if true == ok then
                torrent:assoc_blist(blist_table)
                torrent:trackers_peers()
                table.insert(results_table, "[" .. fullPath .. "] seeders[" .. torrent.num_seeders .. 
                              "] leeches[" .. torrent.num_leeches .. "]")
            else
              local text = "[" .. fullPath .. "] <-- Load failed [" .. err_text .. "]"

              stdnse.debug(0, " -->" .. text)
              table.insert(results_table, text)
            end
          end
        else
          -- process a directory
          --
          browseFolder(fullPath)
        end
      end
    end
  end

  -- recurse the given directory
  --
  browseFolder(recurse_dir)

  -- return the output table to caller
  --
  return stdnse.format_output(true, results_table)
end


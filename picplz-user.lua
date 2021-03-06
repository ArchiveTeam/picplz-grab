--
-- Picplz.com download script for Wget-lua
--
-- From the initial API result of one user, this script generates and
-- enqueues new URLs to download all the data and images of that user.
--
-- This script works if you run Wget with this seed URL:
--  http://api.picplz.com/api/v2/user.json?id=${user_id}&include_detail=1&include_pics=1&pic_page_size=1000
--

JSON = (loadfile "JSON.lua")()
dofile("table_show.lua")

load_json_file = function(file)
  local f = io.open(file)
  local data = f:read("*all")
  f:close()
  return JSON:decode(data)
end

-- for statistics
local n_pictures_done = 0
local n_pictures_total = 0
local n_images_done = 0
local n_images_total = 0

local first_user_json = true

wget.callbacks.get_urls = function(file, url, is_css, iri)
  local urls = {}

  local api_section = string.match(url, "api.picplz.com/api/v2/([a-z]+)")
  if api_section then
    local d = load_json_file(file)

    local value = d["value"]
    if value then
      if api_section == "user" and value["users"] then
        -- user details
        local user = value["users"][1]
        if user then
          -- show to user
          if first_user_json then
            local str = " - User "..user["id"]..", http://picplz.com/user/"..user["username"].."/, "..user["display_name"]
            str = string.gsub(str, "[^\32-\126]", "")
            print(str)
          end

          if user["pics"] == nil then
            user["pics"] = {}
          end

          local n = #(user["pics"])
          if n == 1 then
            print(" - Discovered 1 picture")
          else
            print(" - Discovered "..n.." pictures")
          end
          n_pictures_total = n_pictures_total + n

          -- add picture urls
          for i, pic in pairs(user["pics"]) do
            table.insert(urls, { url="http://api.picplz.com/api/v2/pic.json?include_items=1&pic_formats=56s,64s,100s,400r,640r,1024r&id="..pic["id"] })
          end

          -- add icon url
          local icon = user["icon"]
          if icon and icon["url"] then
            table.insert(urls, { url=icon["url"] })
          end

          -- add followers and following
          table.insert(urls, { url="http://api.picplz.com/api/v2/followers.json?include_user=1&page_size=100&id="..user["id"] })
          table.insert(urls, { url="http://api.picplz.com/api/v2/following.json?include_user=1&page_size=100&id="..user["id"] })

          -- WEB: add user page
          table.insert(urls, { url="http://picplz.com/user/"..user["username"].."/", link_expect_html=1 })

          -- picture pagination
          if user["more_pics"] then
            local next_url = url
            next_url = string.gsub(next_url, "&last_pic_id=[0-9]+", "")
            next_url = next_url.."&last_pic_id="..user["last_pic_id"]
            table.insert(urls, { url=next_url })
          end

          -- store user data
          picplz_lua_json = os.getenv("picplz_lua_json")
          if picplz_lua_json and first_user_json then
            local fs = io.open(picplz_lua_json, "w")
            fs:write(JSON:encode({ id=user["id"], username=user["username"], display_name=user["display_name"] }))
            fs:close()
            picplz_lua_json_written = true
          end

          first_user_json = false
        end

      elseif (api_section == "followers" or api_section == "following") and value["users"] then
        -- followers or following

        -- show to user
        local n = #(value["users"])
        if n == 1 then
          print(" - Discovered 1 user in "..api_section)
        else
          print(" - Discovered "..n.." users in "..api_section)
        end

        -- user pagination
        if value["more"] then
          local next_url = url
          next_url = string.gsub(next_url, "&last_id=[0-9]+", "")
          next_url = next_url.."&last_id="..value["last_id"]
          table.insert(urls, { url=next_url })
        end

      elseif api_section == "pic" and value["pics"] then
        -- picture details
        local pic = value["pics"][1]
        if pic then
          -- show stats
          n_pictures_done = n_pictures_done + 1
          if n_pictures_done % 100 == 0 or n_pictures_done == n_pictures_total then
            print(" - Downloaded "..n_pictures_done.." of "..n_pictures_total.." picture details")
          end

          -- add image urls
          for i, pic_file in pairs(pic["pic_files"]) do
            table.insert(urls, { url=pic_file["img_url"] })
            n_images_total = n_images_total + 1
          end

          -- WEB: add picture page
          if pic["url"] then
            table.insert(urls, { url="http://picplz.com"..pic["url"], link_expect_html=1 })
          end
        end

      end
    end

  elseif string.match(url, "/img/") then
    -- show stats
    n_images_done = n_images_done + 1
    if n_images_done % 100 == 0 or n_images_done == n_images_total then
      print(" - Downloaded "..n_images_done.." of an estimated "..n_images_total.." images")
    end

  else
    local m = string.match(url, "^http://picplz.com/user/([^/]+)/$")
    if m then
      -- the user page
      for line in io.lines(file) do
        local page_context = string.match(line, "var page_context = ({.+});")
        if page_context then
          page_context = JSON:decode(page_context)

          -- generate the first API request for the 'infinite scrolling' page
          --
          -- NOTE: the JavaScript functions add a _ parameter with a timestamp
          -- to the API request. We can't really archive the timestamps, so
          -- we archive the urls without a timestamp. This does mean that the
          -- resurrected page will request URLs that aren't archived: remove
          -- the timestamp parameter and it will work.
          --
          if page_context["last_id"] then
            table.insert(urls, { url="http://picplz.com/api/v1/picfeed_get?last_id="..
                                     page_context["last_id"]..
                                     "&user_id="..page_context["user_id"]..
                                     "&predicate=recent&view_type=list" })
          end

          break
        end
      end

    else
      m = string.match(url, "^http://picplz.com/api/v1/picfeed_get.*user_id=([0-9]+).*")
      if m then
        local d = load_json_file(file)
        local value = d["value"]
        if value and value["last_id"] then
          table.insert(urls, { url="http://picplz.com/api/v1/picfeed_get?last_id="..
                                   value["last_id"]..
                                   "&user_id="..m..
                                   "&predicate=recent&view_type=list" })
        end
      end
    end
  end

  return urls
end

wget.callbacks.download_child_p = function(urlpos, parent, depth, start_url_parsed, iri, verdict)
  local host = urlpos["url"]["host"]
  if host == "maps.google.com" or host == "ajax.googleapis.com" then
    return verdict
  elseif string.match(host, "picplzthumbs.com") then
    return verdict
  elseif string.match(host, "cloudfront.net") then
    return verdict
  else
    return false
  end
end



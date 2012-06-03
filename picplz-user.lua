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
          -- add picture urls
          for i, pic in pairs(user["pics"]) do
            table.insert(urls, { url="http://api.picplz.com/api/v2/pic.json?include_items=1&pic_formats=56s,64s,100s,400r,640r,1024r&id="..pic["id"] })
          end

          -- show to user
          local n = #(user["pics"])
          if n == 1 then
            print(" - Discovered 1 picture")
          else
            print(" - Discovered "..n.." pictures")
          end
          n_pictures_done = 0
          n_pictures_total = n_pictures_total + n

          -- add icon url
          local icon = user["icon"]
          if icon and icon["url"] then
            table.insert(urls, { url=icon["url"] })
            n_images_total = n_images_total + 1
          end

          -- add followers and following
          table.insert(urls, { url="http://api.picplz.com/api/v2/followers.json?include_user=1&page_size=100&id="..user["id"] })
          table.insert(urls, { url="http://api.picplz.com/api/v2/following.json?include_user=1&page_size=100&id="..user["id"] })

          -- WEB: add user page
          table.insert(urls, { url="http://picplz.com/user/"..user["username"].."/" })

          -- picture pagination
          if user["more_pics"] then
            local next_url = url
            next_url = string.gsub(next_url, "&last_pic_id=[0-9]+", "")
            next_url = next_url.."&last_pic_id="..user["last_pic_id"]
            table.insert(urls, { url=next_url })
          end

          -- store user data
          picplz_lua_json = os.getenv("picplz_lua_json")
          if picplz_lua_json then
            local fs = io.open(picplz_lua_json, "w")
            fs:write(JSON:encode({ id=user["id"], username=user["username"], display_name=user["display_name"] }))
            fs:close()
          end
        end

      elseif (api_section == "followers" or api_section == "following") and value["users"] then
        -- followers or following

        -- show to user
        local n = value["user_count"]
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
            table.insert(urls, { url="http://picplz.com"..pic["url"] })
          end
        end

      end
    end

  elseif string.match(url, "/img/") then
    -- show stats
    n_images_done = n_images_done + 1
    if n_images_done % 100 == 0 or n_images_done == n_images_total then
      print(" - Downloaded "..n_images_done.." of "..n_images_total.." images")
    end
  end

  return urls
end



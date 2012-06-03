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
          -- picture pagination
          if user["more_pics"] then
            local next_url = url
            next_url = string.gsub(next_url, "&last_pic_id=[0-9]+", "")
            next_url = next_url.."&last_pic_id="..user["last_pic_id"]
            table.insert(urls, { url=next_url })
          end

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
          table.insert(urls, { url="http://picplz.com/user/"..user["username"].."/" })

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

        -- user pagination
        if value["more"] then
          local next_url = url
          next_url = string.gsub(next_url, "&last_id=[0-9]+", "")
          next_url = next_url.."&last_id="..user["last_id"]
          table.insert(urls, { url=next_url })
        end

      elseif api_section == "pic" and value["pics"] then
        -- picture details
        local pic = value["pics"][1]
        if pic then
          -- add image urls
          for i, pic_file in pairs(pic["pic_files"]) do
            table.insert(urls, { url=pic_file["img_url"] })
          end

          -- WEB: add picture page
          if pic["url"] then
            table.insert(urls, { url="http://picplz.com"..pic["url"] })
          end
        end

      end
    end
  end

  return urls
end



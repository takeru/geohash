# ruby port of geohash-native.c
# (c) 2009 sasaki.takeru@gmail.com

=begin
// geohash-native.c
// (c) 2008 David Troy
// dave@roundhousetech.com
// 
// (The MIT License)
// 
// Copyright (c) 2008 David Troy, Roundhouse Technologies LLC
// 
// Permission is hereby granted, free of charge, to any person obtaining
// a copy of this software and associated documentation files (the
// 'Software'), to deal in the Software without restriction, including
// without limitation the rights to use, copy, modify, merge, publish,
// distribute, sublicense, and/or sell copies of the Software, and to
// permit persons to whom the Software is furnished to do so, subject to
// the following conditions:
// 
// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.
// 
// THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
// IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
// CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
// TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
// SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
=end

class GeoHash
  BASE32 = "0123456789bcdefghjkmnpqrstuvwxyz"

  def self.decode_geohash_bbox(geohash, lat, lon)
    is_even = true

    lat[0] = -90.0;  lat[1] = 90.0;
    lon[0] = -180.0; lon[1] = 180.0;
    lat_err = 90.0;  lon_err = 180.0;

    geohash.downcase.split("").each_with_index do |c,i|
      cd = BASE32.index(c)
      [16,8,4,2,1].each_with_index do |mask,j|
        if is_even
          lon_err /= 2
          lon[(cd&mask)==0 ? 1 : 0] = (lon[0] + lon[1])/2
        else
          lat_err /= 2
          lat[(cd&mask)==0 ? 1 : 0] = (lat[0] + lat[1])/2
        end
        is_even = !is_even
      end
    end
  end

  def self.decode_geohash(geohash, point)
    lat = [0.0, 0.0]
    lon = [0.0, 0.0]
    decode_geohash_bbox(geohash, lat, lon)
    point[0] = (lat[0] + lat[1]) / 2
    point[1] = (lon[0] + lon[1]) / 2
  end

  def self.encode_geohash(latitude, longitude, precision)
    geohash = ""

    is_even = true
    i    = 0
    lat  = [ -90.0,  90.0]
    lon  = [-180.0, 180.0]
    bits = [16,8,4,2,1]
    bit  = 0
    ch   = 0

    while i<precision
      if is_even
        mid = (lon[0] + lon[1]) / 2
        if longitude > mid
          ch |= bits[bit]
          lon[0] = mid
        else
          lon[1] = mid
        end
      else
        mid = (lat[0] + lat[1]) / 2
        if latitude > mid
          ch |= bits[bit]
          lat[0] = mid
        else
          lat[1] = mid
        end
      end
      is_even = !is_even
      if bit < 4
        bit += 1
      else
        geohash << BASE32[ch]
        i += 1
        bit = 0
        ch = 0
      end
    end
    return geohash
  end

  def self.encode_base(lat, lon, precision)
    digits = precision || 10
    if digits<3 || digits>12
      digits = 12
    end
    return encode_geohash(lat, lon, digits)
  end

  def self.decode_bbox(str)
    lat = [0.0, 0.0]
    lon = [0.0, 0.0]
    decode_geohash_bbox(str, lat, lon)
    return [[lat[0], lon[0]], [lat[1], lon[1]]]
  end

  def self.decode_base(str)
    point = [0.0, 0.0]
    decode_geohash(str, point)
    return point
  end

  # Given a particular geohash string, a direction, and a final length
  # Compute a neighbor using base32 lookups, recursively when necessary
  def self.get_neighbor(str, dir, hashlen)
    # Right, Left, Top, Bottom
    neighbors = ["bc01fg45238967deuvhjyznpkmstqrwx",
                 "238967debc01fg45kmstqrwxuvhjyznp",
                 "p0r21436x8zb9dcf5h7kjnmqesgutwvy",
                 "14365h7k9dcfesgujnmqp0r2twvyx8zb" ]
    borders = ["bcfguvyz", "0145hjnp", "prxz", "028b"]

    index = ( 2 * (hashlen % 2) + dir) % 4
    neighbor = neighbors[index]
    border = borders[index]
    last_chr = str[hashlen-1, 1]
    if border.index(last_chr)
      get_neighbor(str, dir, hashlen-1)
    end
    str[hashlen-1, 1] = BASE32[neighbor.index(last_chr),1]
  end

  # Acts as Ruby API wrapper to get_neighbor function, which is recursive and does nasty C things
  def self.calculate_adjacent(geohash, dir)
    return nil if geohash.empty?
    ret = geohash.dup
    get_neighbor(ret, dir, geohash.size)
    return ret
  end
end

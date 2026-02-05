require 'net/http'
require 'json'

ELASTIC = 'http://localhost:8888'
SPARQL = 'http://localhost:4027/sparql'

def elastic(path, allowed_groups, test = nil)
  uri = URI(ELASTIC + path)
  req = Net::HTTP::Get.new(uri)
  allowed_groups_object = allowed_groups.map { |group| { "name" => group, "variables" => [] } }
  req['MU_AUTH_ALLOWED_GROUPS'] = allowed_groups_object.to_json

  res = Net::HTTP.start(uri.hostname, uri.port) { |http|
    http.request(req)
  }

  case res
  when Net::HTTPSuccess, Net::HTTPRedirection
    result = JSON.parse(res.body)
    if test
      result == test
    else
      result
    end
  else
    res.value
  end
end

def sparql(allowed_groups, query)
  uri = URI SPARQL
  req = Net::HTTP::Post.new(uri)
  allowed_groups_object = allowed_groups.map { |group| { "name" => group, "variables" => [] } }

  req['MU_AUTH_ALLOWED_GROUPS'] = allowed_groups_object.to_json
  req.set_form_data('query' => query)

  res = Net::HTTP.start(uri.hostname, uri.port) { |http|
    http.request(req)
  }

  case res
  when Net::HTTPSuccess, Net::HTTPRedirection
    JSON.parse(res.body)
  else
    res.value
  end
end

def run_test(value, label = nil)
  result = yield
  if value == result
    puts label ? "OK   #{label}" : "OK"
  else
    msg = label ? "FAIL #{label}" : "FAIL"
    raise "\n#{msg}\nExpected: #{value}\nReceived: #{result}\n"
  end
end


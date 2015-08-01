require 'sinatra'
require 'sqlite3'
require 'securerandom'
require 'sinatra/json'
require 'rack/auth/digest/md5'
require './domain.rb'
set :bind, '0.0.0.0'

db = SQLite3::Database.new "db/vote.db"
db.results_as_hash = true

helpers do
  def protected!
    unless authorized?
      response['WWW-Authenticate'] = %(Basic realm="Restricted Area")
      throw(:halt, [401, "Not authorized\n"])
    end
  end
  def authorized?
    @auth ||=  Rack::Auth::Basic::Request.new(request.env)
    @auth.provided? && @auth.basic? && @auth.credentials && @auth.credentials == ['changeme', 'changeme'] 
  end
end

get '/' do
  votes = db.execute("SELECT * FROM votes ORDER BY id DESC LIMIT 10")
  erb :index, { :locals => { :posts => votes } }
end

post '/add' do
  file_name = ""
  if params["file"]
    ext = ""
    if params["file"][:type].include? "jpeg"
      ext = "jpg"
    elsif params["file"][:type].include? "png"
      ext = "png"
    else
      return "投稿できる画像形式はjpgとpngだけです。"
    end
    # 適当なファイル名をつける
    file_name = SecureRandom.hex + "." + ext
    
    # 画像を保存
    File.open("./public/uploads/" + file_name, 'wb') do |f|
      f.write params["file"][:tempfile].read
    end
  else
    return "画像が必須です"
  end

  stmt = db.prepare("INSERT INTO votes (img_uri) VALUES(?)")
  stmt.bind_params(file_name)
  stmt.execute
  #redirect '/'
end

get '/vote/like/:vote_id' do
	vote_id = params[:vote_id].to_i
  vote = db.execute("SELECT voting_count, good_count FROM votes WHERE id = ?", vote_id)
	if vote.empty?
		return "error"
	end
  new_vote_count = vote[0]["voting_count"] + 1
  new_good_count = vote[0]["good_count"] + 1
  stmt = db.prepare("UPDATE votes SET voting_count = ?, good_count = ?  WHERE id = ?")
  stmt.bind_params(new_vote_count, new_good_count, vote_id)
  stmt.execute

  body = { "voting_count" => new_vote_count }
	status  = 200
	headers "Access-Control-Allow-Origin" => "#{$allowed_domain}",
					"Access-Control-Allow-Headers" => "Content-Type",
					"Access-Control-Allow-Methods" => "PUT,DELETE,POST,GET,OPTIONS"
	response = [status, headers, body]
	json body
end

get '/vote/dislike/:vote_id' do
	vote_id = params[:vote_id].to_i
  vote = db.execute("SELECT voting_count FROM votes WHERE id = ?", vote_id)
	if vote.empty?
		return "error"
	end
  new_vote_count = vote[0]["voting_count"] + 1
  stmt = db.prepare("UPDATE votes SET voting_count = ? WHERE id = ?")
  stmt.bind_params(new_vote_count, vote_id)
  stmt.execute

  body = { "voting_count" => new_vote_count }
	status  = 200
	headers "Access-Control-Allow-Origin" => "#{$allowed_domain}",
					"Access-Control-Allow-Headers" => "Content-Type",
					"Access-Control-Allow-Methods" => "PUT,DELETE,POST,GET,OPTIONS"
	response = [status, headers, body]
	json body
end

get '/fetch/:post_id' do
	post_id = params[:post_id].to_i
	post = db.execute("SELECT id,img_uri FROM votes WHERE id = ?", post_id)
	if post.empty?
		return "error"
	end
	uri = post[0]["img_uri"]
	id = post[0]["id"]
	body = { "id" => id, "uri" => "#{$root_domain}"+"/public/uploads/#{uri}" }
	status  = 418
	headers "Access-Control-Allow-Origin" => "#{$allowed_domain}",
					"Access-Control-Allow-Headers" => "Content-Type",
					"Access-Control-Allow-Methods" => "PUT,DELETE,POST,GET,OPTIONS"
	response = [status, headers, body]
	json body
end

get '/public/uploads/:file.:ext' do |file, ext|
	content_type ext
	send_file "public/uploads/#{file}.#{ext}"
end

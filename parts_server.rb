# Copyright 2012 Team 254. All Rights Reserved.
# @author pat@patfairbank.com (Patrick Fairbank)
#
# The main class of the parts management web server.

require "pathological"
require "sinatra/base"

require "models"

module CheesyParts
  class Server < Sinatra::Base
    PART_TYPES = ["part", "assembly"]

    set :sessions => true

    before do
      @user = User[session[:user_id]]
      authenticate! unless request.path == "/login"
    end

    def authenticate!
      redirect "/login?redirect=#{request.path}" if @user.nil?
    end

    get "/" do
      redirect "/projects"
    end

    get "/login" do
      redirect "/logout" if @user
      @failed = params[:failed] == "1"
      @redirect = params[:redirect] || "/"
      erb :login
    end

    post "/login" do
      user = User.authenticate(params[:email], params[:password])
      redirect "/login?failed=1" if user.nil?
      session[:user_id] = user.id
      redirect params[:redirect]
    end

    get "/logout" do
      session[:user_id] = nil
      redirect "/"
    end

    get "/new_project" do
      erb :new_project
    end

    get "/projects" do
      erb :projects
    end

    post "/projects" do
      # Check parameter existence and format.
      halt(400, "Missing project name.") if params[:name].nil?
      if params[:part_number_prefix].nil? || params[:part_number_prefix] !~ /^\d+$/
        halt(400, "Missing or invalid part number prefix.")
      end

      project = Project.create(:name => params[:name], :part_number_prefix => params[:part_number_prefix])
      redirect "/projects/#{project.id}"
    end

    get "/projects/:id" do
      @project = Project[params[:id]]
      halt(400, "Invalid project.") if @project.nil?
      erb :project
    end

    get "/projects/:id/edit" do
      @project = Project[params[:id]]
      halt(400, "Invalid project.") if @project.nil?
      erb :project_edit
    end

    post "/projects/:id/edit" do
      @project = Project[params[:id]]
      halt(400, "Invalid project.") if @project.nil?
      @project.name = params[:name] if params[:name]
      if params[:part_number_prefix]
        halt(400, "Invalid part number prefix.") if params[:part_number_prefix] !~ /^\d+$/
        @project.part_number_prefix = params[:part_number_prefix]
      end
      @project.save
      redirect "/projects/#{params[:id]}"
    end

    get "/projects/:id/delete" do
      @project = Project[params[:id]]
      halt(400, "Invalid project.") if @project.nil?
      erb :project_delete
    end

    post "/projects/:id/delete" do
      @project = Project[params[:id]]
      halt(400, "Invalid project.") if @project.nil?
      @project.delete
      redirect "/projects"
    end

    get "/projects/:id/dashboard" do
      @project = Project[params[:id]]
      halt(400, "Invalid project.") if @project.nil?
      erb :dashboard
    end

    get "/projects/:id/new_part" do
      @project = Project[params[:id]]
      halt(400, "Invalid project.") if @project.nil?
      @parent_part_id = params[:parent_part_id]
      @type = params[:type] || "part"
      halt(400, "Invalid part type.") unless PART_TYPES.include?(@type)
      erb :new_part
    end

    post "/parts" do
      # Check parameter existence and format.
      halt(400, "Missing project ID.") if params[:project_id].nil? || params[:project_id] !~ /^\d+$/
      halt(400, "Missing part type.") if params[:type].nil?
      halt(400, "Invalid part type.") unless PART_TYPES.include?(params[:type])
      halt(400, "Missing part name.") if params[:name].nil?
      if params[:parent_part_id] && params[:parent_part_id] !~ /^\d+$/
        halt(400, "Invalid parent part ID.")
      end

      project = Project[params[:project_id].to_i]
      halt(400, "Invalid project.") if project.nil?

      parent_part = nil
      if params[:parent_part_id]
        parent_part = Part[:id => params[:parent_part_id].to_i, :project_id => project.id,
                           :type => "assembly"]
        halt(400, "Invalid parent part.") if parent_part.nil?
      end

      part = Part.generate_number_and_create(project, params[:type], params[:name], parent_part,
                                             params[:notes])
      redirect "/parts/#{part.id}"
    end

    get "/parts/:id" do
      @part = Part[params[:id]]
      halt(400, "Invalid part.") if @part.nil?
      erb :part
    end

    get "/parts/:id/edit" do
      @part = Part[params[:id]]
      halt(400, "Invalid part.") if @part.nil?
      erb :part_edit
    end

    post "/parts/:id/edit" do
      @part = Part[params[:id]]
      halt(400, "Invalid part.") if @part.nil?
      @part.name = params[:name] if params[:name]
      if params[:status]
        halt(400, "Invalid status.") unless Part::STATUS_MAP.include?(params[:status])
        @part.status = params[:status]
      end
      @part.notes = params[:notes] if params[:notes]
      @part.save
      redirect "/parts/#{params[:id]}"
    end

    get "/parts/:id/delete" do
      @part = Part[params[:id]]
      halt(400, "Invalid part.") if @part.nil?
      erb :part_delete
    end

    post "/parts/:id/delete" do
      @part = Part[params[:id]]
      project_id = @part.project_id
      halt(400, "Invalid part.") if @part.nil?
      halt(400, "Can't delete assembly with existing children.") unless @part.child_parts.empty?
      @part.delete
      redirect "/projects/#{project_id}"
    end

    get "/new_user" do
      erb :new_user
    end

    get "/users" do
      erb :users
    end

    post "/users" do
      halt(400, "Missing email.") if params[:email].nil? || params[:email].empty?
      halt(400, "User #{params[:email]} already exists.") if User[:email => params[:email]]
      halt(400, "Missing password.") if params[:password].nil? || params[:password].empty?
      halt(400, "Missing permission.") if params[:permission].nil? || params[:permission].empty?
      halt(400, "Invalid permission.") unless User::PERMISSION_MAP.include?(params[:permission])
      User.secure_create(params[:email], params[:password], params[:permission])
      redirect "/users"
    end

    get "/users/:id/edit" do
      @user_edit = User[params[:id]]
      halt(400, "Invalid user.") if @user_edit.nil?
      erb :user_edit
    end

    post "/users/:id/edit" do
      @user_edit = User[params[:id]]
      halt(400, "Invalid user.") if @user_edit.nil?
      @user_edit.email = params[:email] if params[:email]
      @user_edit.change_password(params[:password]) if params[:password] && !params[:password].empty?
      @user_edit.permission = params[:permission] if params[:permission]
      @user_edit.save
      redirect "/users"
    end

    get "/users/:id/delete" do
      @user_delete = User[params[:id]]
      halt(400, "Invalid user.") if @user_delete.nil?
      erb :user_delete
    end

    post "/users/:id/delete" do
      @user_delete = User[params[:id]]
      halt(400, "Invalid user.") if @user_delete.nil?
      @user_delete.delete
      redirect "/users"
    end
  end
end

#encoding: utf-8
class ContestsolutionsController < ApplicationController
  before_action :signed_in_user_danger, only: [:create, :update, :destroy, :reserve_sol, :unreserve_sol]
  before_action :check_contests, only: [:create, :update, :destroy, :reserve_sol, :unreserve_sol] # Defined in application_controller.rb
  before_action :get_contestproblem, only: [:create]
  before_action :get_contestsolution, only: [:update, :destroy, :reserve_sol, :unreserve_sol]
  before_action :can_send_solution, only: [:create, :update]
  before_action :can_delete_solution, only: [:destroy]
  before_action :is_organizer, only: [:reserve_sol, :unreserve_sol]
  before_action :can_reserve, only: [:reserve_sol, :unreserve_sol]

  # Créer une nouvelle solution
  def create
    if @send_solution == 2 # Can happen if we have two windows and we try to create twice a solution to a same problem
      update and return
    end
  
    params[:contestsolution][:content].strip! if !params[:contestsolution][:content].nil?
    # Pièces jointes
    @error = false
    @error_message = ""

    attach = create_files # Fonction commune pour toutes les pièces jointes

    if @error
      flash[:danger] = @error_message
      session[:ancientexte] = params[:contestsolution][:content]
      redirect_to contestproblem_path(@contestproblem) and return
    end

    solution = @contestproblem.contestsolutions.build(content: params[:contestsolution][:content])
    solution.user = current_user.sk

    # Si on réussit à sauver
    if solution.save
      j = 1
      while j < attach.size()+1 do
        attach[j-1].update_attribute(:myfiletable, solution)
        attach[j-1].save
        j = j+1
      end

      flash[:success] = "Solution enregistrée."
      
      correction = Contestcorrection.new
      correction.content = "-"
      correction.contestsolution = solution
      correction.save
      
      redirect_to contestproblem_path(@contestproblem, :sol => solution)
      
      # Si il y a eu une erreur
    else
      destroy_files(attach, attach.size()+1)
      session[:ancientexte] = params[:contestsolution][:content]
      if params[:contestsolution][:content].size == 0
        flash[:danger] = "Votre solution est vide."
      else
        flash[:danger] = "Une erreur est survenue."
      end
      redirect_to contestproblem_path(@contestproblem)
    end
  end

  # Modifier une solution
  def update  
    if @send_solution == 1 # Not normal
      redirect_to @contestproblem
    end
    
    params[:contestsolution][:content].strip! if !params[:contestsolution][:content].nil?
    @contestsolution.content = params[:contestsolution][:content]
    if @contestsolution.valid?
      totalsize = 0

      @contestsolution.myfiles.each do |f|
        if params["prevfile#{f.id}".to_sym].nil?
          f.file.destroy
          f.destroy
        else
          totalsize = totalsize + f.file_file_size
        end
      end

      @contestsolution.fakefiles.each do |f|
        if params["prevfakefile#{f.id}".to_sym].nil?
          f.destroy
        end
      end

      @error = false
      @error_message = ""

      update_files(@contestsolution) # Fonction commune pour toutes les pièces jointes

      if @error
        flash[:danger] = @error_message
        session[:ancientexte] = params[:contestsolution][:content]
        redirect_to contestproblem_path(@contestproblem, :sol => @contestsolution) and return
      end
      
      @contestsolution.save
      flash[:success] = "Solution enregistrée."
      redirect_to contestproblem_path(@contestproblem, :sol => @contestsolution)
    else
      session[:ancientexte] = params[:contestsolution][:content]
      if params[:contestsolution][:content].size == 0
        flash[:danger] = "Votre solution est vide."
      else
        flash[:danger] = "Une erreur est survenue."
      end
      redirect_to contestproblem_path(@contestproblem, :sol => @contestsolution)
    end
  end

  def destroy
    if current_user.other
      flash[:danger] = "Vous êtes dans la peau de quelqu'un d'autre !"
    else
      flash[:success] = "Solution supprimée."
      @contestsolution.destroy
    end
    redirect_to contestproblem_path(@contestproblem)
  end
  
  # Réserver la solution
  def reserve_sol
    if @contestsolution.reservation == current_user.sk.id
      @ok = 1
    elsif @contestsolution.reservation > 0
      @correct_name = User.find(@contestsolution.reservation).name
      @ok = 0
    else
      @contestsolution.reservation = current_user.sk.id
      @contestsolution.save
      @ok = 1
    end
  end

  # Dé-réserver la solution
  def unreserve_sol
    @contestsolution.reservation = 0
    @contestsolution.save
  end

  ########## PARTIE PRIVEE ##########
  private

  # Récupère le problème
  def get_contestproblem
    @contestproblem = Contestproblem.find_by_id(params[:contestproblem_id])
    if @contestproblem.nil?
      render 'errors/access_refused' and return
    end
    @contest = @contestproblem.contest
  end
  
  def get_contestsolution
    @contestsolution = Contestsolution.find_by_id(params[:id])
    if @contestsolution.nil?
      render 'errors/access_refused' and return
    end
    @contestproblem = @contestsolution.contestproblem
    @contest = @contestproblem.contest
  end
  
  def can_send_solution
    @send_solution = 0
    mycontestsolution = nil
    if !@contest.is_organized_by_or_admin(current_user) && @contestproblem.status == 2
      mycontestsolution = @contestproblem.contestsolutions.where(:user => current_user.sk).first
      if !mycontestsolution.nil?
        @send_solution = 2
      elsif current_user.sk.rating >= 200
        @send_solution = 1
      end
    end
    
    if @send_solution == 0 || (@send_solution == 2 && mycontestsolution != @contestsolution)
      flash[:danger] = "Vous ne pouvez pas modifier cette solution."
      redirect_to @contestproblem
    end
  end
  
  def can_delete_solution
    unless @contestproblem.status == 2 && !@contestsolution.official && @contestsolution.user == current_user.sk
      flash[:danger] = "Vous ne pouvez pas supprimer cette solution."
      redirect_to @contestproblem
    end
  end
  
  def is_organizer
    if !@contest.is_organized_by(current_user)
      render 'errors/access_refused' and return
    end
  end
  
  def can_reserve
    if @contestproblem.status != 3 && @contestproblem.status != 5 && !@contestsolution.official?
      redirect_to @contestproblem
    end
  end
end

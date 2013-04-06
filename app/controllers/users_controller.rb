#encoding: utf-8
class UsersController < ApplicationController
  before_filter :signed_in_user,
    only: [:destroy, :index, :edit, :update, :show, :create_administrator, :recompute_scores, :notification_new, :notification_update, :notifs_show]
  before_filter :correct_user,
    only: [:edit, :update]
  before_filter :admin_user,
    only: [:destroy, :notification_new, :notification_update]
  before_filter :root_user,
    only: [:create_administrator, :recompute_scores]
  before_filter :signed_out_user,
    only: [:new, :create]
  before_filter :destroy_admin,
    only: [:destroy]

  def index
  end
  def create
    @user = User.new(params[:user])
    @user.key = SecureRandom.urlsafe_base64
    # @user.email_confirm = false <-- A décommenter pour rendre les mails utiles!
  	if @user.save
  	  # UserMailer.registration_confirmation(@user).deliver
  	  # flash[:success] = "Un mail de confirmation vous a été envoyé sur votre adresse mail pour activer votre compte."
  	  flash[:success] = "Vous êtes inscrit! Veuillez vous connecter."
  	  redirect_to signin_path
  	else
  	  render 'new'
  	end
  end
  def show
    @user = User.find(params[:id])
  end
  def new
  	@user = User.new
  end
  def edit
  end
  def update
    if @user.update_attributes(params[:user])
      flash[:success] = "Profil mis à jour."
      sign_in @user
      redirect_to @user
    else
      render 'edit'
    end
  end
  def destroy
    @user.destroy
    flash[:success] = "Utilisateur supprimé."
    redirect_to users_path
  end

  def create_administrator
    @user = User.find(params[:user_id])
    if @user.admin?
      flash[:error] = "I see what you did here! Mais non ;-)"
    else
      @user.toggle!(:admin)
      flash[:success] = "Utilisateur promu au rang d'administrateur!"
    end
    redirect_to users_path
  end

  def activate
    @user = User.find(params[:id])
    if !@user.email_confirm && @user.key.to_s == params[:key].to_s
      @user.toggle!(:email_confirm)
      flash[:success] = "Votre compte a bien été activé! Veuillez maintenant vous connecter."
    elsif @user.key.to_s != params[:key].to_s
      flash[:error] = "Le lien d'activation est erroné."
    else
      flash[:notice] = "Ce compte est déjà actif!"
    end
    redirect_to signin_path
  end

  def recompute_scores
    User.all.each do |user|
      point_attribution(user)
    end
    redirect_to users_path
  end

  def notifications_new
    @notifications = Submission.order("updated_at DESC").paginate(page: params[:page]).all
    @new = true
    render :notifications
  end

  def notifications_update
    @notifications = current_user.followed_submissions.order("updated_at DESC").paginate(page: params[:page]).all
    @new = false
    render :notifications
  end
  
  def notifs_show
    @notifs = current_user.notifs.order("created_at")
    render :notifs
  end

  private

  def signed_out_user
    if signed_in?
      redirect_to root_path
    end
  end
  def correct_user
    @user = User.find(params[:id])
    redirect_to root_path unless current_user?(@user)
  end
  def admin_user
    redirect_to root_path unless current_user.admin?
  end
  def root_user
    redirect_to root_path unless current_user.root
  end
  def destroy_admin
    @user = User.find(params[:id])
    if @user.admin?
      flash[:error] = "One does not simply destroy an admin."
      redirect_to root_path
    end
  end

  def point_attribution(user)
    user.point.rating = 0
    partials = user.pointspersections
    partial = Array.new
    partial[0] = partials.where(:section_id => 0).first
    partial[0].points = 0
    Section.all.each do |s|
      partial[s.id] = partials.where(:section_id => s.id).first
      partial[s.id].points = 0
    end

    user.solvedexercises.each do |e|
      if e.correct
        exo = e.exercise
        if exo.decimal
          pt = 10
        else
          pt = 6
        end

        if !exo.chapter.sections.empty? # Pas un fondement
          user.point.rating = user.point.rating + pt
        else # Fondement
          partial[0].points = partial[0].points + pt
        end

        exo.chapter.sections.each do |s| # Section s
          partial[s.id].points = partial[s.id].points + pt
        end
      end
    end

    user.solvedqcms.each do |q|
      if q.correct
        qcm = q.qcm
        poss = qcm.choices.count
        if qcm.many_answers
          pt = 2*(poss-1)
        else
          pt = poss
        end

        if !qcm.chapter.sections.empty? # Pas un fondement
          user.point.rating = user.point.rating + pt
        else # Fondement
          partial[0].points = partial[0].points + pt
        end

        qcm.chapter.sections.each do |s| # Section s
          partial[s.id].points = partial[s.id].points + pt
        end
      end
    end

    user.solvedproblems.each do |p|
      problem = p.problem
      pt = 25*problem.level

      if !problem.chapter.sections.empty? # Pas un fondement
        user.point.rating = user.point.rating + pt
      else # Fondement
        partial[0].points = partial[0].points + pt
      end

      problem.chapter.sections.each do |s| # Section s
        partial[s.id].points = partial[s.id].points + pt
      end
    end

    user.point.save
    partial[0].save
    Section.all.each do |s|
      partial[s.id].save
    end

  end

end

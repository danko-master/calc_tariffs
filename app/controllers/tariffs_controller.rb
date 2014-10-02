class TariffsController < ApplicationController
  def index
    @tariffs = Tariff.all
  end

  def new
    @tariff = Tariff.new
  end

  def edit
    @tariff = Tariff.find params[:id]
  end

  def create
    @tariff = Tariff.new _params
    @tariff.save
    redirect_to tariffs_path
  end

  def update
    @tariff = Tariff.find params[:id]
    @tariff.update(_params)
    redirect_to tariffs_path
  end

  def destroy
    @tariff = Tariff.find params[:id]
    @tariff.destroy
    redirect_to tariffs_path
  end

  private
  def _params
    params.require(:tariff).permit(:note, :code, :started_at, :is_active)
  end
end

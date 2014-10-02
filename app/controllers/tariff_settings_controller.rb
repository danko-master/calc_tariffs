class TariffSettingsController < ApplicationController
  def index
    @tariff_settings = TariffSetting.all
  end

  def new
    @tariff_setting = TariffSetting.new
  end

  def edit
    @tariff_setting = TariffSetting.find params[:id]
  end

  def create
    @tariff_setting = TariffSetting.new _params
    @tariff_setting.save
    redirect_to tariff_settings_path
  end

  def update
    @tariff_setting = TariffSetting.find params[:id]
    @tariff_setting.update(_params)
    redirect_to tariff_settings_path
  end

  def destroy
    @tariff_setting = TariffSetting.find params[:id]
    @tariff_setting.destroy
    redirect_to tariff_settings_path
  end

  private
  def _params
    params.require(:tariff_setting).permit(:code)
  end
end

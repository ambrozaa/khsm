require 'rails_helper'

# Тест на шаблон users/show.html.erb

RSpec.describe 'users/show', type: :view do
  before(:each) do
    current_user = assign(:user, FactoryGirl.build_stubbed(:user, name: 'Vitaly'))
    allow(view).to receive(:current_user).and_return(current_user)

    render
  end

  # Проверяем, что шаблон выводит имена игроков
  it 'renders player names' do
    expect(rendered).to match 'Vitaly'
  end

  it 'player sees link' do
    expect(rendered).to match 'Сменить имя и пароль'
  end

end

require 'rails_helper'
require 'support/my_spec_helper' # наш собственный класс с вспомогательными методами

# Тестовый сценарий для модели Игры
# В идеале - все методы должны быть покрыты тестами,
# в этом классе содержится ключевая логика игры и значит работы сайта.
RSpec.describe Game, type: :model do
  # пользователь для создания игр
  let(:user) { FactoryGirl.create(:user) }

  # игра с прописанными игровыми вопросами
  let(:game_w_questions) { FactoryGirl.create(:game_with_questions, user: user) }

  # Группа тестов на работу фабрики создания новых игр
  context 'Game Factory' do
    it 'Game.create_game! new correct game' do
      # генерим 60 вопросов с 4х запасом по полю level,
      # чтобы проверить работу RANDOM при создании игры
      generate_questions(60)

      game = nil
      # создaли игру, обернули в блок, на который накладываем проверки
      expect {
        game = Game.create_game_for_user!(user)
      }.to change(Game, :count).by(1).and(# проверка: Game.count изменился на 1 (создали в базе 1 игру)
        change(GameQuestion, :count).by(15).and(# GameQuestion.count +15
          change(Question, :count).by(0) # Game.count не должен измениться
        )
      )
      # проверяем статус и поля
      expect(game.user).to eq(user)
      expect(game.status).to eq(:in_progress)
      # проверяем корректность массива игровых вопросов
      expect(game.game_questions.size).to eq(15)
      expect(game.game_questions.map(&:level)).to eq (0..14).to_a
    end
  end

  # тесты на основную игровую логику
  context 'game mechanics' do

    # правильный ответ должен продолжать игру
    it 'answer correct continues game' do
      # текущий уровень игры и статус
      level = game_w_questions.current_level
      q = game_w_questions.current_game_question
      expect(game_w_questions.status).to eq(:in_progress)

      game_w_questions.answer_current_question!(q.correct_answer_key)

      # перешли на след. уровень
      expect(game_w_questions.current_level).to eq(level + 1)
      # ранее текущий вопрос стал предыдущим
      expect(game_w_questions.previous_game_question).to eq(q)
      expect(game_w_questions.current_game_question).not_to eq(q)
      # игра продолжается
      expect(game_w_questions.status).to eq(:in_progress)
      expect(game_w_questions.finished?).to be_falsey
    end

    it 'take_money finish game' do
      q = game_w_questions.current_game_question
      game_w_questions.answer_current_question!(q.correct_answer_key)
      game_w_questions.take_money!

      prize = game_w_questions.prize
      expect(prize).to be > 1

      expect(game_w_questions.finished?).to be_truthy
      expect(prize).to eq(user.balance)
    end

    context '.status' do
      before(:each) do
        game_w_questions.finished_at = Time.now
        expect(game_w_questions.finished_at).to be_truthy

      end

      it '.won' do
        game_w_questions.current_level = Question::QUESTION_LEVELS.max + 1
        expect(game_w_questions.status).to eq(:won)
      end

      it '.fail' do
        game_w_questions.is_failed = true
        expect(game_w_questions.status).to eq(:fail)
      end

      it '.money' do
        game_w_questions.current_level = Question::QUESTION_LEVELS.max
        expect(game_w_questions.status).to eq(:money)
      end
    end

    context '.current_game_question' do
      it 'returns the question for the current level' do
        expect(game_w_questions.current_game_question).to eq(game_w_questions.game_questions.find_by(game_id: 1))
      end

      it 'returns the previous level' do
        game_w_questions.current_level = 2
        expect(game_w_questions.previous_level).to eq(1)
      end
    end

    context '.answer_current_question!' do
      let(:q) { game_w_questions.current_game_question }

      it 'correct answer' do
        expect(game_w_questions.answer_current_question!('d')).to be_truthy
        expect(game_w_questions.status).to eq(:in_progress)
        expect(game_w_questions.finished?).to be_falsey
      end

      it 'wrong answer' do
        expect(game_w_questions.answer_current_question!('a')).to be_falsey
        expect(game_w_questions.status).to eq(:fail)
        expect(game_w_questions.finished?).to be_truthy
      end

      it 'last answer' do
        game_w_questions.current_level = Question::QUESTION_LEVELS.max
        expect(game_w_questions.answer_current_question!('d')).to be_truthy
        expect(game_w_questions.status).to eq(:won)
        expect(game_w_questions.finished?).to be_truthy
      end

      it 'answer after time' do
        game_w_questions.created_at = 1.hour.ago
        expect(game_w_questions.answer_current_question!('d')).to be_falsey
        expect(game_w_questions.status).to eq(:timeout)
        expect(game_w_questions.finished?).to be_truthy
      end

    end
  end
end
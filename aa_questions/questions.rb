require 'sqlite3'
require 'singleton'

class QuestionDBConnection < SQLite3::Database
  include Singleton

  def initialize
    super('questions.db')
    self.type_translation = true
    self.results_as_hash = true
  end
end

class Question
  attr_accessor :title, :body, :author_id
  attr_reader :id

  def self.find_by_id(id)
    question = QuestionDBConnection.instance.execute(<<-SQL, id)
      SELECT
        *
      FROM
        questions
      WHERE
        id = ?
    SQL
    return nil unless question.length > 0

    Question.new(question.first)
  end

  def self.find_by_author_id(author_id)
    questions = QuestionDBConnection.instance.execute(<<-SQL, author_id)
      SELECT
        *
      FROM
        questions
      WHERE
        author_id = ?
    SQL
    return nil unless questions.length > 0

    questions.map do |question|
      Question.new(question)
    end

  end

  def initialize(options)
    @id = options['id']
    @title = options['title']
    @body = options['body']
    @author_id = options['author_id']
  end

  def author
    User.find_by_id(@author_id)
  end

  def replies
    Reply.find_by_question_id(@id)
  end

  def followers
    QuestionFollow.followers_for_question_id(@id)
  end
end

class User
  attr_accessor :fname, :lname
  attr_reader :id

  def self.find_by_id(id)
    user = QuestionDBConnection.instance.execute(<<-SQL, id)
      SELECT
        *
      FROM
        users
      WHERE
        id = ?
    SQL
    return nil unless user.length > 0

    User.new(user.first)
  end

  def self.find_by_name(fname, lname)
    user = QuestionDBConnection.instance.execute(<<-SQL, fname, lname)
      SELECT
        *
      FROM
        users
      WHERE
        fname = ? AND lname = ?
    SQL
    return nil unless user.length > 0

    User.new(user.first)
  end

  def initialize(options)
    @id = options['id']
    @fname = options['fname']
    @lname = options['lname']
  end

  def authored_questions
    Question.find_by_author_id(@id)
  end

  def authored_replies
    Replies.find_by_author_id(@id)
  end

  def followed_questions
    QuestionFollow.followed_questions_for_user_id(@id)
  end

end

class QuestionFollow
  attr_accessor :follower_id, :question_id
  attr_reader :id

  def self.find_by_id(id)
    question_follow = QuestionDBConnection.instance.execute(<<-SQL, id)
      SELECT
        *
      FROM
        question_follows
      WHERE
        id = ?
    SQL
    return nil unless question_follow.length > 0

    QuestionFollow.new(question_follow.first)
  end

  def self.followers_for_question_id(question_id)
    followers = QuestionDBConnection.instance.execute(<<-SQL, question_id)
      SELECT
        b.*
      FROM
        question_follows AS a
      JOIN
        users AS b ON a.follower_id = b.id
      WHERE
        question_id = ?
    SQL
    return nil unless followers.length > 0

    followers.map { |follower| User.new(follower) }
  end

  def self.followed_questions_for_user_id(user_id)
    questions = QuestionDBConnection.instance.execute(<<-SQL, user_id)
      SELECT
        b.*
      FROM
        question_follows AS a
      JOIN
        questions AS b ON a.question_id = b.id
      WHERE
        follower_id = ?
    SQL
    return nil unless questions.length > 0

    questions.map { |question| Question.new(question) }
  end

  def initialize(options)
    @id = options['id']
    @follower_id = options['follower_id']
    @question_id = options['question_id']
  end

end


class QuestionLike
  attr_accessor :user_id, :question_id
  attr_reader :id

  def self.find_by_id(id)
    question_like = QuestionDBConnection.instance.execute(<<-SQL, id)
      SELECT
        *
      FROM
        question_likes
      WHERE
        id = ?
    SQL
    return nil unless question_like.length > 0

    QuestionLike.new(question_like.first)
  end

  def initialize(options)
    @id = options['id']
    @user_id = options['user_id']
    @question_id = options['question_id']
  end
end

class Reply
  attr_accessor :question_id, :parent_id, :author_id, :body
  attr_reader :id

  def self.find_by_id(id)
    reply = QuestionDBConnection.instance.execute(<<-SQL, id)
      SELECT
        *
      FROM
        replies
      WHERE
        id = ?
    SQL
    return nil unless reply.length > 0

    Reply.new(reply.first)
  end

  def self.find_by_user_id(author_id)
    replies = QuestionDBConnection.instance.execute(<<-SQL, author_id)
      SELECT
        *
      FROM
        replies
      WHERE
        author_id = ?
    SQL
    return nil unless replies.length > 0

    replies.map do |reply|
      Reply.new(reply)
    end
  end

  def self.find_by_question_id(question_id)
    replies = QuestionDBConnection.instance.execute(<<-SQL, question_id)
      SELECT
        *
      FROM
        replies
      WHERE
        question_id = ?
    SQL
    return nil unless replies.length > 0

    replies.map do |reply|
      Reply.new(reply)
    end
  end

  def initialize(options)
    @id = options['id']
    @question_id = options['question_id']
    @body = options['body']
    @parent_id = options['parent_id']
    @author_id = options['author_id']
  end

  def author
    User.find_by_id(@author_id)
  end

  def question
    Question.find_by_id(@question_id)
  end

  def parent_reply
    Reply.find_by_id(@parent_id)
  end

  def child_replies
    replies = QuestionDBConnection.instance.execute(<<-SQL, @id)
      SELECT
        *
      FROM
        replies
      WHERE
        parent_id = ?
    SQL
    return nil unless replies.length > 0

    replies.map do |reply|
      Reply.new(reply)
    end
  end
end

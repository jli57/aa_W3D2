require 'sqlite3'
require 'singleton'
require 'active_support/inflector'

class QuestionDBConnection < SQLite3::Database
  include Singleton

  def initialize
    super('questions.db')
    self.type_translation = true
    self.results_as_hash = true
  end
end

class QuestionBase
  def self.table
     self.to_s.tableize
  end

  def self.find_by_id(id)
    results = QuestionDBConnection.instance.execute(<<-SQL, id)
      SELECT
        *
      FROM
        #{table}
      WHERE
        id = ?
    SQL
    return nil unless results.length > 0
    self.new(results.first)
  end

  def self.all
    results = QuestionDBConnection.instance.execute(<<-SQL)
      SELECT
        *
      FROM
        #{table}
    SQL
    parse_all(results)
  end

  def self.where(options)
    if options.is_a?(String)
      where_condition = options
    else
      values = options.values
      where_condition = options.keys.map { | col_name | "#{col_name} = ?" }.join(" AND ")
    end
    
    results = QuestionDBConnection.instance.execute(<<-SQL, *values)
      SELECT
        *
      FROM
        #{table}
      WHERE
        #{where_condition}
    SQL
    return nil unless results.length > 0
    self.parse_all(results)
  end

  def self.find_by(options)
    where(options)
  end

  def save
    if @id
      update
    else
      create
    end
  end

  def attrs
    Hash[instance_variables.map do |name|
      [name.to_s[1..-1], instance_variable_get(name)]
    end]
  end

  def create
    raise "#{self} already in database" if @id

    instance_attrs = attrs
    instance_attrs.delete("id")
    col_names = instance_attrs.keys.join(", ")
    question_marks = (["?"] * instance_attrs.count).join(", ")
    values = instance_attrs.values

    QuestionDBConnection.instance.execute(<<-SQL, *values)
      INSERT INTO
        #{self.class.table} (#{col_names})
      VALUES
        (#{question_marks})
    SQL
    @id = QuestionDBConnection.instance.last_insert_row_id
  end

  def update
    raise "#{self} not in database" unless @id

    instance_attrs = attrs
    instance_attrs.delete("id")
    set_line = instance_attrs.keys.map { |attr| "#{attr} = ?" }.join(", ")
    values = instance_attrs.values

    QuestionDBConnection.instance.execute(<<-SQL, *values, id)
      UPDATE
        #{self.class.table}
      SET
        #{set_line}
      WHERE
        id = ?
    SQL
  end

  def self.parse_all(results)
    results.map { |result| self.new(result) }
  end
end

class Question < QuestionBase
  attr_accessor :title, :body, :author_id
  attr_reader :id, :table_name

  def self.generate(questions)
    questions.map { |question| Question.new(question) }
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

  def self.most_followed(n)
    QuestionFollow.most_followed_questions(n)
  end

  def self.most_liked(n)
    QuestionLike.most_liked_questions(n)
  end

  def initialize(options)
    @id = options['id']
    @title = options['title']
    @body = options['body']
    @author_id = options['author_id']
    @table_name = 'questions'
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

  def likers
    QuestionLike.likers_for_question_id(@id)
  end

  def num_likes
    QuestionLike.num_likes_for_question_id(@id)
  end

  def save
    if @id
      update
    else
      create
    end
  end

  private

  def create
    raise "#{self} already in database" if @id
    QuestionDBConnection.instance.execute(<<-SQL,  @title, @body, @author_id)
      INSERT INTO
        questions (title, body, author_id)
      VALUES
        (?, ?, ?)
    SQL
    @id = QuestionDBConnection.instance.last_insert_row_id
  end

  def update
    raise "#{self} not in database" unless @id
    QuestionDBConnection.instance.execute(<<-SQL,  @title, @body, @author_id, @id)
      UPDATE
        questions
      SET
        title = ?, body = ?, author_id = ?
      WHERE
        id = ?
    SQL
  end
end

class User < QuestionBase
  attr_accessor :fname, :lname
  attr_reader :id

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

  def liked_questions
    QuestionLike.liked_questions_for_user_id(@id)
  end

  def average_karma
    avg_karma = QuestionDBConnection.instance.execute(<<-SQL, @id)
      SELECT
        COALESCE( ( COUNT(*) / CAST( COUNT(DISTINCT a.id) AS float ) ), 0) AS avg_karma
      FROM
        questions AS a
      LEFT JOIN
        question_likes AS b
      ON
        a.id = b.question_id
      WHERE
        a.author_id = ?
    SQL
    avg_karma.first['avg_karma']
  end

  def save
    if @id
      update
    else
      create
    end
  end

  private

  def create
    raise "#{self} already in database" if @id
    QuestionDBConnection.instance.execute(<<-SQL, @fname, @lname)
      INSERT INTO
        users (fname, lname)
      VALUES
        (?, ?)
    SQL
    @id = QuestionDBConnection.instance.last_insert_row_id
  end

  def update
    raise "#{self} not in database" unless @id
    QuestionDBConnection.instance.execute(<<-SQL,  @fname, @lname, @id)
      UPDATE
        users
      SET
        fname = ?, lname = ?
      WHERE
        id = ?
    SQL
  end

end

class QuestionFollow < QuestionBase
  attr_accessor :follower_id, :question_id
  attr_reader :id

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

  def self.most_followed_questions(n)
    questions = QuestionDBConnection.instance.execute(<<-SQL, n)
      SELECT
        a.*
      FROM
        questions a
      JOIN (
          SELECT
            question_id, COUNT(id) AS count
          FROM
            question_follows AS a
          GROUP BY
            question_id
        ) b ON a.id = b.question_id
      ORDER BY
        b.count DESC
      LIMIT
        ?
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


class QuestionLike < QuestionBase
  attr_accessor :user_id, :question_id
  attr_reader :id


  def self.likers_for_question_id(question_id)
    likers = QuestionDBConnection.instance.execute(<<-SQL, question_id)
      SELECT
        b.*
      FROM
        question_likes AS a
      JOIN
        users AS b ON a.user_id = b.id
      WHERE
        question_id = ?
    SQL
    return nil unless likers.length > 0

    likers.map { |liker| User.new(liker) }
  end

  def self.num_likes_for_question_id(question_id)
    num_likes = QuestionDBConnection.instance.execute(<<-SQL, question_id)
      SELECT
        COUNT(*) AS count
      FROM
        question_likes
      WHERE
        question_id = ?
    SQL
    num_likes.first['count']
  end

  def self.liked_questions_for_user_id(user_id)
    liked_questions = QuestionDBConnection.instance.execute(<<-SQL, user_id)
      SELECT
        b.*
      FROM
        question_likes AS a
      JOIN
        questions AS b ON a.question_id = b.id
      WHERE
        user_id = ?
    SQL
    return nil unless liked_questions.length > 0

    liked_questions.map { |liked_question| Question.new(liked_question) }
  end

  def self.most_liked_questions(n)
    questions = QuestionDBConnection.instance.execute(<<-SQL, n)
      SELECT
        a.*
      FROM
        questions a
      JOIN (
          SELECT
            question_id, COUNT(id) AS count
          FROM
            question_likes AS a
          GROUP BY
            question_id
        ) b ON a.id = b.question_id
      ORDER BY
        b.count DESC
      LIMIT
        ?
    SQL
    return nil unless questions.length > 0

    questions.map { |question| Question.new(question) }
  end

  def initialize(options)
    @id = options['id']
    @user_id = options['user_id']
    @question_id = options['question_id']
  end
end

class Reply < QuestionBase
  attr_accessor :question_id, :parent_id, :author_id, :body
  attr_reader :id

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

  def save
    if @id
      update
    else
      create
    end
  end

  private

  def create
    raise "#{self} already in database" if @id
    QuestionDBConnection.instance.execute(<<-SQL, @question_id, @body, @parent_id, @author_id)
      INSERT INTO
        replies (question_id, body, parent_id, author_id )
      VALUES
        (?, ?, ?, ?)
    SQL
    @id = QuestionDBConnection.instance.last_insert_row_id
  end

  def update
    raise "#{self} not in database" unless @id
    QuestionDBConnection.instance.execute(<<-SQL, @question_id, @body, @parent_id, @author_id, @id)

      UPDATE
        replies
      SET
        question_id = ?, body = ?, parent_id = ?, author_id = ?
      WHERE
        id = ?
    SQL
  end
end

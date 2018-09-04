PRAGMA foreign_keys = ON;

DROP TABLE IF EXISTS replies;
DROP TABLE IF EXISTS question_follows;
DROP TABLE IF EXISTS question_likes;
DROP TABLE IF EXISTS questions;
DROP TABLE IF EXISTS users;

CREATE TABLE users (
  id INTEGER PRIMARY KEY,
  fname TEXT NOT NULL,
  lname TEXT NOT NULL
);

CREATE TABLE questions (
  id INTEGER PRIMARY KEY,
  title TEXT NOT NULL,
  body TEXT,
  author_id INTEGER NOT NULL,

  FOREIGN KEY (author_id) REFERENCES users(id)
);

CREATE TABLE question_follows (
  id INTEGER PRIMARY KEY,
  follower_id INTEGER NOT NULL,
  question_id INTEGER NOT NULL,

  FOREIGN KEY (follower_id) REFERENCES users(id),
  FOREIGN KEY (question_id) REFERENCES questions(id)
);

CREATE TABLE question_likes (
  id INTEGER PRIMARY KEY,
  user_id INTEGER NOT NULL,
  question_id INTEGER NOT NULL,

  FOREIGN KEY (user_id) REFERENCES users(id),
  FOREIGN KEY (question_id) REFERENCES questions(id)
);

CREATE TABLE replies (
  id INTEGER PRIMARY KEY,
  author_id INTEGER NOT NULL,
  question_id INTEGER NOT NULL,
  parent_id INTEGER,
  body TEXT,

  FOREIGN KEY (author_id) REFERENCES users(id),
  FOREIGN KEY (question_id) REFERENCES questions(id),
  FOREIGN KEY (parent_id) REFERENCES replies(id)
);

INSERT INTO users (fname, lname)
VALUES
('Alice', 'Yang'),
('Jingna', 'Li'),
('AJ','Gosling'),
('Danny','Xu'),
('Chris','Atwood');

INSERT INTO questions (title, body, author_id)
VALUES
('How to use Sqlite3?', 'Someone help me!', 3),
('What does foreign key mean?', 'I have no idea what it is!', 4),
('Can I go home?', 'I''m so tired!', 1);

INSERT INTO question_follows ( follower_id, question_id )
VALUES
(2, 3),
(2, 2),
(1, 1),
(3, 2),
(4, 1),
(4, 2),
(5, 3);

INSERT INTO question_likes ( user_id, question_id )
VALUES
(2, 3),
(3, 1),
(1, 3),
(4, 2),
(5, 3),
(4, 1);

INSERT INTO replies ( author_id, question_id, parent_id, body )
VALUES
( 2, 3, NULL, 'Probably after 6pm -_-'),
( 1, 1, NULL, 'Read the readings!'),
( 5, 3, 1, 'That''s in 3 hours!'),
( 3, 2, NULL, 'The foreign key is the primary key of a table being referenced in a different table'),
( 4, 2, 4, 'Smartass!'),
( 2, 2, 5, '(╯°□°）╯︵ ┻━┻');

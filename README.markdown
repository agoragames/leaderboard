# leaderboard

Leaderboards backed by [Redis](http://redis.io) in Ruby.

Builds off ideas proposed in http://blog.agoragames.com/2011/01/01/creating-high-score-tables-leaderboards-using-redis/.

[![Build Status](https://secure.travis-ci.org/agoragames/leaderboard.png)](http://travis-ci.org/agoragames/leaderboard)

## Installation

`gem install leaderboard`

or in your `Gemfile`

```ruby
gem 'leaderboard'
```

Make sure your redis server is running! Redis configuration is outside the scope of this README, but
check out the [Redis documentation](http://redis.io/documentation).

## Compatibility

The gem has been built and tested under Ruby 1.8.7, Ruby 1.9.2 and Ruby 1.9.3.

The gem is compatible with Redis 2.4.x and Redis 2.6.x.

## Usage

### Creating a leaderboard

Be sure to require the leaderboard library:

```ruby
require 'leaderboard'
```

Create a new leaderboard or attach to an existing leaderboard named 'highscores':

```ruby
  highscore_lb = Leaderboard.new('highscores')
   => #<Leaderboard:0x0000010307b530 @leaderboard_name="highscores", @page_size=25, @redis_connection=#<Redis client v2.2.2 connected to redis://localhost:6379/0 (Redis v2.2.5)>>
```

If you need to pass in options for Redis, you can do this in the initializer:

```ruby
  redis_options = {:host => 'localhost', :port => 6379, :db => 1}
   => {:host=>"localhost", :port=>6379, :db=>1}
  highscore_lb = Leaderboard.new('highscores', Leaderboard::DEFAULT_OPTIONS, redis_options)
   => #<Leaderboard:0x00000103095200 @leaderboard_name="highscores", @page_size=25, @redis_connection=#<Redis client v2.2.2 connected to redis://localhost:6379/1 (Redis v2.2.5)>>
```

### Defining leaderboard options

The `Leaderboard::DEFAULT_OPTIONS` are as follows:

```ruby
DEFAULT_OPTIONS = {
  :page_size => DEFAULT_PAGE_SIZE,
  :reverse => false
}
```

The `DEFAULT_PAGE_SIZE` is 25.

You would use the option, `:reverse => true`, if you wanted a leaderboard sorted from lowest-to-highest score. You
may also set the `reverse` option on a leaderboard after you have created a new instance of a leaderboard.

You can pass in an existing connection to Redis using `:redis_connection` in the Redis options hash:

```ruby
  redis = Redis.new
   => #<Redis client v2.2.2 connected to redis://127.0.0.1:6379/0 (Redis v2.2.5)>
  redis_options = {:redis_connection => redis}
   => {:redis_connection=>#<Redis client v2.2.2 connected to redis://127.0.0.1:6379/0 (Redis v2.2.5)>}
  highscore_lb = Leaderboard.new('highscores', Leaderboard::DEFAULT_OPTIONS, redis_options)
   => #<Leaderboard:0x000001028791e8 @leaderboard_name="highscores", @page_size=25, @redis_connection=#<Redis client v2.2.2 connected to redis://127.0.0.1:6379/0 (Redis v2.2.5)>>
```

To use the same connection for multiple leaderboards, reset the options hash before instantiating more leaderboards:

```ruby
redis = Redis.new
 => #<Redis client v2.2.2 connected to redis://127.0.0.1:6379/0 (Redis v2.2.5)>
redis_options = {:redis_connection => redis}
 => {:redis_connection=>#<Redis client v2.2.2 connected to redis://127.0.0.1:6379/0 (Redis v2.2.5)>}
highscore_lb = Leaderboard.new('highscores', Leaderboard::DEFAULT_OPTIONS, redis_options)
redis_options = {:redis_connection => redis}
other_highscore_lb = Leaderboard.new('other_highscores', Leaderboard::DEFAULT_OPTIONS, redis_options)
```

You can set the page size to something other than the default page size (25):

```ruby
  highscore_lb.page_size = 5
   => 5
  highscore_lb
   => #<Leaderboard:0x000001028791e8 @leaderboard_name="highscores", @page_size=5, @redis_connection=#<Redis client v2.2.2 connected to redis://127.0.0.1:6379/0 (Redis v2.2.5)>>
```

### Ranking members in the leaderboard

Add members to your leaderboard using `rank_member`:

```ruby
  1.upto(10) do |index|
    highscore_lb.rank_member("member_#{index}", index)
  end
   => 1
```

You can call `rank_member` with the same member and the leaderboard will be updated automatically.

Get some information about your leaderboard:

```ruby
  highscore_lb.total_members
   => 10
  highscore_lb.total_pages
   => 1
```

The `rank_member` call will also accept an optional parameter, `member_data` that could
be used to store other information about a given member in the leaderboard. This
may be useful in situations where you are storing member IDs in the leaderboard and
you want to be able to store a member name for display. You could use JSON to
encode a Hash of member data. Example:

```ruby
require 'json'
highscore_lb.rank_member('84849292', 1, JSON.generate({'username' => 'member_name'})
```

You can retrieve, update and remove the optional member data using the
`member_data_for`, `update_member_data` and `remove_member_data` calls. Example:

```ruby
JSON.parse(highscore_lb.member_data_for('84849292'))
 => {"username"=>"member_name"}

highscore_lb.update_member_data('84849292', JSON.generate({'last_updated' => Time.now, 'username' => 'updated_member_name'}))
 => "OK"
JSON.parse(highscore_lb.member_data_for('84849292'))
 => {"username"=>"updated_member_name", "last_updated"=>"2012-06-09 09:11:06 -0400"}

highscore_lb.remove_member_data('84849292')
```

If you delete the leaderboard, ALL of the member data is deleted as well.

#### Optional member data notes

If you use optional member data, the use of the `remove_members_in_score_range` will leave data around in the member data
hash. This is because the internal Redis method, `zremrangebyscore`, only returns the number of items removed. It does
not return the members that it removed.

Get some information about a specific member(s) in the leaderboard:

```ruby
  highscore_lb.score_for('member_4')
   => 4.0
  highscore_lb.rank_for('member_4')
   => 7
  highscore_lb.rank_for('member_10')
   => 1
```

### Retrieving members from the leaderboard

Get page 1 in the leaderboard:

```ruby
  highscore_lb.leaders(1)
   => [{:member=>"member_10", :rank=>1, :score=>10.0}, {:member=>"member_9", :rank=>2, :score=>9.0}, {:member=>"member_8", :rank=>3, :score=>8.0}, {:member=>"member_7", :rank=>4, :score=>7.0}, {:member=>"member_6", :rank=>5, :score=>6.0}, {:member=>"member_5", :rank=>6, :score=>5.0}, {:member=>"member_4", :rank=>7, :score=>4.0}, {:member=>"member_3", :rank=>8, :score=>3.0}, {:member=>"member_2", :rank=>9, :score=>2.0}, {:member=>"member_1", :rank=>10, :score=>1.0}]
```

You can pass various options to the calls `leaders`, `all_leaders`, `around_me`, `members_from_score_range`, `members_from_rank_range` and `ranked_in_list`. Valid options are:

* `:with_member_data` - `true` or `false` (default) to return the optional member data.
* `:page_size` - An integer value to change the page size for that call.
* `:members_only` - `true` or `false` (default) to return only the members without their score and rank.
* `:sort_option` - Valid values for `:sort_option` are `:none` (default), `:score` and `:rank`.

You can also use the `members` and `members_in` methods as aliases for the `leaders` and `leaders_in` methods.

There are also a few convenience methods to be able to retrieve all leaders from a given leaderboard. They are `all_leaders` and `all_leaders_from`. You may also use the aliases `all_members` or `all_members_from`. Use any of these methods sparingly as all the information in the leaderboard will be returned.

Add more members to your leaderboard:

```ruby
  50.upto(95) do |index|
    highscore_lb.rank_member("member_#{index}", index)
  end
   => 50
  highscore_lb.total_pages
   => 3
```

Get an "Around Me" leaderboard page for a given member, which pulls members above and below the given member:

```ruby
  highscore_lb.around_me('member_53')
   => [{:member=>"member_65", :rank=>31, :score=>65.0}, {:member=>"member_64", :rank=>32, :score=>64.0}, {:member=>"member_63", :rank=>33, :score=>63.0}, {:member=>"member_62", :rank=>34, :score=>62.0}, {:member=>"member_61", :rank=>35, :score=>61.0}, {:member=>"member_60", :rank=>36, :score=>60.0}, {:member=>"member_59", :rank=>37, :score=>59.0}, {:member=>"member_58", :rank=>38, :score=>58.0}, {:member=>"member_57", :rank=>39, :score=>57.0}, {:member=>"member_56", :rank=>40, :score=>56.0}, {:member=>"member_55", :rank=>41, :score=>55.0}, {:member=>"member_54", :rank=>42, :score=>54.0}, {:member=>"member_53", :rank=>43, :score=>53.0}, {:member=>"member_52", :rank=>44, :score=>52.0}, {:member=>"member_51", :rank=>45, :score=>51.0}, {:member=>"member_50", :rank=>46, :score=>50.0}, {:member=>"member_10", :rank=>47, :score=>10.0}, {:member=>"member_9", :rank=>48, :score=>9.0}, {:member=>"member_8", :rank=>49, :score=>8.0}, {:member=>"member_7", :rank=>50, :score=>7.0}, {:member=>"member_6", :rank=>51, :score=>6.0}, {:member=>"member_5", :rank=>52, :score=>5.0}, {:member=>"member_4", :rank=>53, :score=>4.0}, {:member=>"member_3", :rank=>54, :score=>3.0}, {:member=>"member_2", :rank=>55, :score=>2.0}]
```

Get rank and score for an arbitrary list of members (e.g. friends) from the leaderboard:

```ruby
  highscore_lb.ranked_in_list(['member_1', 'member_62', 'member_67'])
   => [{:member=>"member_1", :rank=>56, :score=>1.0}, {:member=>"member_62", :rank=>34, :score=>62.0}, {:member=>"member_67", :rank=>29, :score=>67.0}]
```

Retrieve members from the leaderboard in a given score range:

```ruby
members = highscore_lb.members_from_score_range(4, 19)
 => [{:member=>"member_10", :rank=>47, :score=>10.0}, {:member=>"member_9", :rank=>48, :score=>9.0}, {:member=>"member_8", :rank=>49, :score=>8.0}, {:member=>"member_7", :rank=>50, :score=>7.0}, {:member=>"member_6", :rank=>51, :score=>6.0}, {:member=>"member_5", :rank=>52, :score=>5.0}, {:member=>"member_4", :rank=>53, :score=>4.0}]
```

Retrieve a single member from the leaderboard at a given position:

```ruby
members = highscore_lb.member_at(4)
 => {:member=>"member_92", :rank=>4, :score=>92.0}
```

Retrieve a range of members from the leaderboard within a given rank range:

```ruby
members = highscore_lb.members_from_rank_range(1, 5)
 => [{:member=>"member_95", :rank=>1, :score=>95.0}, {:member=>"member_94", :rank=>2, :score=>94.0}, {:member=>"member_93", :rank=>3, :score=>93.0}, {:member=>"member_92", :rank=>4, :score=>92.0}, {:member=>"member_91", :rank=>5, :score=>91.0}]
```

The option `:sort_option` is useful for retrieving an arbitrary list of
members from a given leaderboard where you would like the data sorted
when returned. The follow examples demonstrate its use:

```ruby
friends = highscore_lb.ranked_in_list(['member_6', 'member_1', 'member_10'], :sort_by => :rank)
 => [{:member=>"member_10", :rank=>47, :score=>10.0}, {:member=>"member_6", :rank=>51, :score=>6.0}, {:member=>"member_1", :rank=>56, :score=>1.0}]
```

```ruby
friends = highscore_lb.ranked_in_list(['member_6', 'member_1', 'member_10'], :sort_by => :score)
 => [{:member=>"member_1", :rank=>56, :score=>1.0}, {:member=>"member_6", :rank=>51, :score=>6.0}, {:member=>"member_10", :rank=>47, :score=>10.0}]
```

### Conditionally rank a member in the leaderboard

You can pass a lambda to the `rank_member_if` method to conditionally rank a member in the leaderboard. The lambda is passed the following 5 parameters:

* `member`: Member name.
* `current_score`: Current score for the member in the leaderboard. May be `nil` if the member is not currently ranked in the leaderboard.
* `score`: Member score.
* `member_data`: Optional member data.
* `leaderboard_options`: Leaderboard options, e.g. :reverse => Value of reverse option

```ruby
highscore_check = lambda do |member, current_score, score, member_data, leaderboard_options|
  return true if current_score.nil?
  return true if score > current_score
  false
end

highscore_lb.rank_member_if(highscore_check, 'david', 1337)
highscore_lb.score_for('david')
 => 1337.0
highscore_lb.rank_member_if(highscore_check, 'david', 1336)
highscore_lb.score_for('david')
 => 1337.0
highscore_lb.rank_member_if(highscore_check, 'david', 1338)
highscore_lb.score_for('david')
 => 1338.0
```

NOTE: Use a lambda and not a proc, otherwise you will get a `LocalJumpError` as a return statement in the proc will return from the method enclosing the proc.

### Ranking multiple members in a leaderboard at once

Insert multiple data items for members and their associated scores:

As a splat:

```ruby
highscore_lb.rank_members('member_1', 1, 'member_5', 5, 'member_10', 10)
```

Or as an array:

```ruby
highscore_lb.rank_members(['member_1', 1, 'member_5', 5, 'member_10', 10])
```

Use this method to do bulk insert of data, but be mindful of the amount of data you are inserting since a single transaction can get quite large.

### Other useful methods

```
  delete_leaderboard: Delete the current leaderboard
  member_data_for(member): Retrieve the optional member data for a given member in the leaderboard
  update_member_data(member, member_data): Update the optional member data for a given member in the leaderboard
  remove_member_data(member): Remove the optional member data for a given member in the leaderboard
  remove_member(member): Remove a member from the leaderboard
  total_members: Total # of members in the leaderboard
  total_pages: Total # of pages in the leaderboard given the leaderboard's page_size
  total_members_in_score_range(min_score, max_score): Count the number of members within a score range in the leaderboard
  change_score_for(member, delta): Change the score for a member by some amount delta (delta could be positive or negative)
  rank_for(member): Retrieve the rank for a given member in the leaderboard
  score_for(member): Retrieve the score for a given member in the leaderboard
  check_member?(member): Check to see whether member is in the leaderboard
  score_and_rank_for(member): Retrieve the score and rank for a member in a single call
  remove_members_in_score_range(min_score, max_score): Remove members from the leaderboard within a score range
  percentile_for(member): Calculate the percentile for a given member
  page_for(member, page_size): Determine the page where a member falls in the leaderboard
  expire_leaderboard(seconds): Expire the leaderboard in a set number of seconds.
  expire_leaderboard_at(timestamp): Expire the leaderboard at a specific UNIX timestamp.
  rank_members(members_and_scores): Rank an array of members in the leaderboard where you can call via (member_name, score) or pass in an array of [member_name, score]
  merge_leaderboards(destination, keys, options = {:aggregate => :min}): Merge leaderboards given by keys with this leaderboard into destination
  intersect_leaderboards(destination, keys, options = {:aggregate => :min}): Intersect leaderboards given by keys with this leaderboard into destination
```

Check the [online documentation](http://rubydoc.info/gems/leaderboard/frames) for more detail on each method.

## Performance Metrics

10 million sequential scores insert:

```ruby
  highscore_lb = Leaderboard.new('highscores')
   => #<Leaderboard:0x0000010205fc50 @leaderboard_name="highscores", @page_size=25, @redis_connection=#<Redis client v2.2.2 connected to redis://localhost:6379/0 (Redis v2.2.5)>>

  insert_time = Benchmark.measure do
    1.upto(10000000) do |index|
      highscore_lb.rank_member("member_#{index}", index)
    end
  end
   => 323.070000 148.560000 471.630000 (942.068307)
```

Average time to request an arbitrary page from the leaderboard:

```ruby
  requests_to_make = 50000
   => 50000
  lb_request_time = 0
   => 0
  1.upto(requests_to_make) do
    lb_request_time += Benchmark.measure do
      highscore_lb.leaders(rand(highscore_lb.total_pages))
    end.total
  end
   => 1
  p lb_request_time / requests_to_make
  0.001513999999999998
   => 0.001513999999999998
```

10 million random scores insert:

```ruby
  insert_time = Benchmark.measure do
    1.upto(10000000) do |index|
      highscore_lb.rank_member("member_#{index}", rand(50000000))
    end
  end
   => 338.480000 155.200000 493.680000 (2188.702475)
```

Average time to request an arbitrary page from the leaderboard:

```ruby
  1.upto(requests_to_make) do
    lb_request_time += Benchmark.measure do
      highscore_lb.leaders(rand(highscore_lb.total_pages))
    end.total
  end
   => 1
  p lb_request_time / requests_to_make
  0.0014615999999999531
   => 0.0014615999999999531
```

### Bulk insert performance

Ranking individual members:

```ruby
insert_time = Benchmark.measure do
  1.upto(1000000) do |index|
    highscore_lb.rank_member("member_#{index}", index)
  end
end
 =>  29.340000  15.050000  44.390000 ( 81.673507)
```

Ranking multiple members at once:

```ruby
member_data = []
 => []
1.upto(1000000) do |index|
  member_data << "member_#{index}"
  member_data << index
end
 => 1
insert_time = Benchmark.measure do
  highscore_lb.rank_members(member_data)
end
 =>  22.390000   6.380000  28.770000 ( 31.144027)
```

## Ports

The following ports have been made of the leaderboard gem.

Officially supported:

* CoffeeScript: https://github.com/agoragames/leaderboard-coffeescript
* Python: https://github.com/agoragames/leaderboard-python

Unofficially supported (they need some feature parity love):

* Java: https://github.com/agoragames/java-leaderboard
* PHP: https://github.com/agoragames/php-leaderboard
* Scala: https://github.com/agoragames/scala-leaderboard

## Contributing to leaderboard

* Check out the latest master to make sure the feature hasn't been implemented or the bug hasn't been fixed yet
* Check out the issue tracker to make sure someone already hasn't requested it and/or contributed it
* Fork the project
* Start a feature/bugfix branch
* Commit and push until you are happy with your contribution
* Make sure to add tests for it. This is important so I don't break it in a future version unintentionally.
* Please try not to mess with the Rakefile, version, or history. If you want to have your own version, or is otherwise necessary, that is fine, but please isolate to its own commit so I can cherry-pick around it.

## Copyright

Copyright (c) 2011-2013 David Czarnecki. See LICENSE.txt for further details.


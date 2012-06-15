# CHANGELOG

## leaderboard 2.2.0 (in progress)

* Added `leaders_from_score_range` and `leaders_from_score_range_in` methods and specs. This will retrieve leaders from the leaderboard that fall within a given score range.
* Add `leader_at` and `leader_at_in` methods.

## leaderboard 2.1.0 (2012-06-11)

* Added ability to store optional member data alongside the leaderboard data.
* `:with_member_data` is now a valid request option when retrieving leader data.

## leaderboard 2.0.6 (2012-04-26)

* Added accessor for `reverse` option so that you can set reverse after creating a leaderboard to see results in either highest-to-lowest or lowest-to-highest order.

## leaderboard 2.0.5 (2012-03-14)

* Added `rank_members(members_and_scores)` and `rank_members_in(leaderboard_name, members_and_scores)` allowing you to pass in some variable number of `member_name, score` and so on or an actual array of those data items. Use this method to do bulk insert of data, but be mindful of the amount of data you are inserting since a single transaction can get quite large.

## leaderboard 2.0.4 (2012-02-29)

 * Added `page_for(member, page_size = DEFAULT_PAGE_SIZE)` and `page_for_in(leaderboard_name, member, page_size = DEFAULT_PAGE_SIZE)` calls to allow you to determine the page where a member falls in the leaderboard

## leaderboard 2.0.3 (2012-02-22)

 * Added `:reverse => false` to `Leaderboard::DEFAULT_OPTIONS` to support leaderboards sorted from lowest to highest score instead of highest to lowest score. (Thanks @siuying)

## leaderboard 2.0.2 (2012-02-03)

 * Fix for checking to see if a member actually exists in the leaderboard for the `around_me` calls
 * Return appropriate `nil` in data returned for calls such as `percentile_for` and `ranked_in_list` for non-existent members

## leaderboard 2.0.1 (2011-11-07)

 * Allow for only single options to be passed to `leaders`, `around_me` and `ranked_in_list` methods - https://github.com/agoragames/leaderboard/issues/4
 * Added `percentile_for(member)` and `percentile_for_in(leaderboard_name, member)` methods to calculate percentile for a given member
 
## leaderboard 2.0.0 (2011-08-05)
 
 * Change `add_member` to `rank_member` - https://github.com/agoragames/leaderboard/issues/3
 * Added `delete_leaderboard` and `delete_leaderboard_named` - https://github.com/agoragames/leaderboard/issues/2
 * Ability to pass in an existing Redis connection in initializer - https://github.com/agoragames/leaderboard/issues/1
 * Added transaction support for `score_and_rank_for`, `leaders`, `around_me` and `ranked_in_list`
 * Updated initializer to take a leaderboard name, `options` hash and `redis_options` hash
 * Simplified `leaders`, `around_me` and `ranked_in_list` to use an `options` hash with defaults for the previously individual parameters
 
## leaderboard 1.0.6 (unreleased)

 * Added `disconnect` method
 * Check for invalid page size when changing

## leaderboard 1.0.5 (2011-05-04)

 * Updated Rakefile to run tests under ruby 1.8.7 and ruby 1.9.2
 * Added `page_size` parameter to `total_pages_in` to allow for checking what if values in that scenario
 * Added `page_size` parameter to `leaders` and `around_me` calls

## leaderboard 1.0.4 (2011-04-26)

 * Minor bug fix

## leaderboard 1.0.3 (2011-04-26)

 * Fixing issue using total_pages in leaderboard_in call
 * Internal `massage_leader_data` method will now respect `with_scores`
 
## leaderboard 1.0.2 (2011-02-25)

 * Adding `XXX_to`, `XXX_for`, `XXX_in` and `XXX_from` methods that will allow you to set the leaderboard name to interact with outside of creating a new object
 * Added `merge_leaderboards(destination, keys, options = {:aggregate => :min})` method to merge leaderboards given by keys with this leaderboard into destination
 * Added `intersect_leaderboards(destination, keys, options = {:aggregate => :min})` method to intersect leaderboards given by keys with this leaderboard into destination

## leaderboard 1.0.1 (2011-02-16)

 * `redis_options` can be passed in the initializer to pass options for the connection to Redis
 * `page_size` is now settable outside of the initializer
 * `check_member?(member)`: Check to see whether member is in the leaderboard
 * `score_and_rank_for(member, use_zero_index_for_rank = false)`: Retrieve the score and rank for a member in a single call
 * `remove_members_in_score_range(min_score, max_score)`: Remove members from the leaderboard within a score range

## leaderboard 1.0.0

 * Initial release

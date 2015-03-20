# CHANGELOG

## 3.10.0 (Unreleased)

* Fixes TieRankingLeaderboard doesn't rank if the score is 0 [#53](https://github.com/agoragames/leaderboard/issues/53).

## 3.9.0 (2015-02-15)

* Add `global_member_data` option that allows multiple leaderboards to share the same set of member_data. [#51](https://github.com/agoragames/leaderboard/pull/51)
* Add `top` helper method. [#50](https://github.com/agoragames/leaderboard/pull/50).

## 3.8.0 (2014-11-07)

* Add support for `change_score_for(...)` in the `TieRankingLeaderboard` class.

## 3.7.0 (2014-07-28)

* Add support for tie handling in leaderboards [#46](https://github.com/agoragames/leaderboard/pull/46)

## 3.6.0 (2014-02-15)

* Allow for customization of member_data namespace [#45](https://github.com/agoragames/leaderboard/pull/45)

## 3.5.0 (2014-01-24)

* Allow for custom keys to be set for customizing the data returned from calls like `leaders` or `around_me` [#44](https://github.com/agoragames/leaderboard/pull/44)

## 3.4.0 (2013-11-12)

* Added `score_for_percentile` method to be able to calculate the score for a given percentile value in the leaderboard.

## 3.3.0 (2013-07-17)

* Added `rank_member_across` method to be able to rank a member across multiple leaderboards at once.

## 3.2.0 (2013-05-31)

* Added `remove_members_outside_rank` method to remove members from the leaderboard outside a given rank.

## 3.1.0 (2013-05-15)

* Added `:members_only` option for various leaderboard requests.

## 3.0.2 (2013-02-22)

* Fixed a data leak in `expire_leaderboard` and `expire_leaderboard_at` to also set expiration on the member data hash.

## 3.0.1 (2012-12-19)

* Fixed a bug in `remove_member` that would remove all of the optional member data.

## 3.0.0 (2012-12-03)

* Added `rank_member_if` and `rank_member_if_in` methods that allow you to rank a member in the leaderboard based on execution of a lambda.

## 3.0.0.rc2 (2012-11-27)

* No longer cast scores to a floating point automatically. If requesting a score for an unknown member in the leaderboard, return `nil`. Under the old behavior, a `nil` score gets returned as 0.0. This is misleading as 0.0 is a valid score.

## 3.0.0.rc1 (2012-11-08)

* Removes `:use_zero_index_for_rank_option` as valid option for requesting data from the leaderboard. [Original proposal](https://github.com/agoragames/leaderboard/pull/27)
* Optional member data is stored in a single hash. [Original proposal](https://github.com/agoragames/leaderboard/pull/26)
* Adds `:sort_by` as valid option for requesting data from the leaderboard. [Original proposal](https://github.com/agoragames/leaderboard/pull/30)
* Removes `:with_scores` and `:with_ranks` as valid options for requesting data from the leaderboard.

## 2.5.0 (2012-10-12)

* Added `members_from_rank_range` and `members_from_rank_range_in` methods to be able to retrieve members from a leaderboard in a given rank range.

## 2.4.0 (2012-07-30)

* Added `all_leaders` and `all_leaders_from` methods to retrieve all members from a leaderboard. You may also use the aliases `all_members` or `all_members_from`.

## 2.3.0 (2012-07-09)

* Added `expire_leaderboard(seconds)` to expire the leaderboard in a set number of seconds.
* Added `expire_leaderboard_at(timestamp)` to expire the leaderboard at a specific UNIX timestamp.
* Added optional `page_size` parameter to the `total_pages` method.

## 2.2.1 (2012-06-18)

* Fix for #17 - Leaderboard not compatible with redis 2.1.1. Redis' `zrangebyscore` and `zrevrangebyscore` methods do not return scores by default. No need to pass the option in the initial call.

## 2.2.0 (2012-06-18)

* Added `members_from_score_range` and `members_from_score_range_in` methods. These will retrieve members from the leaderboard that fall within a given score range.
* Add `member_at` and `member_at_in` methods. These will retrieve a given member from the leaderboard at the specified position.
* `members` and `members_in` are now aliases for the `leaders` and `leaders_in` methods.

## 2.1.0 (2012-06-11)

* Added ability to store optional member data alongside the leaderboard data.
* `:with_member_data` is now a valid request option when retrieving leader data.

## 2.0.6 (2012-04-26)

* Added accessor for `reverse` option so that you can set reverse after creating a leaderboard to see results in either highest-to-lowest or lowest-to-highest order.

## 2.0.5 (2012-03-14)

* Added `rank_members(members_and_scores)` and `rank_members_in(leaderboard_name, members_and_scores)` allowing you to pass in some variable number of `member_name, score` and so on or an actual array of those data items. Use this method to do bulk insert of data, but be mindful of the amount of data you are inserting since a single transaction can get quite large.

## 2.0.4 (2012-02-29)

 * Added `page_for(member, page_size = DEFAULT_PAGE_SIZE)` and `page_for_in(leaderboard_name, member, page_size = DEFAULT_PAGE_SIZE)` calls to allow you to determine the page where a member falls in the leaderboard

## 2.0.3 (2012-02-22)

 * Added `:reverse => false` to `Leaderboard::DEFAULT_OPTIONS` to support leaderboards sorted from lowest to highest score instead of highest to lowest score. (Thanks @siuying)

## 2.0.2 (2012-02-03)

 * Fix for checking to see if a member actually exists in the leaderboard for the `around_me` calls
 * Return appropriate `nil` in data returned for calls such as `percentile_for` and `ranked_in_list` for non-existent members

## 2.0.1 (2011-11-07)

 * Allow for only single options to be passed to `leaders`, `around_me` and `ranked_in_list` methods - https://github.com/agoragames/leaderboard/issues/4
 * Added `percentile_for(member)` and `percentile_for_in(leaderboard_name, member)` methods to calculate percentile for a given member

## 2.0.0 (2011-08-05)

 * Change `add_member` to `rank_member` - https://github.com/agoragames/leaderboard/issues/3
 * Added `delete_leaderboard` and `delete_leaderboard_named` - https://github.com/agoragames/leaderboard/issues/2
 * Ability to pass in an existing Redis connection in initializer - https://github.com/agoragames/leaderboard/issues/1
 * Added transaction support for `score_and_rank_for`, `leaders`, `around_me` and `ranked_in_list`
 * Updated initializer to take a leaderboard name, `options` hash and `redis_options` hash
 * Simplified `leaders`, `around_me` and `ranked_in_list` to use an `options` hash with defaults for the previously individual parameters

## 1.0.6 (unreleased)

 * Added `disconnect` method
 * Check for invalid page size when changing

## 1.0.5 (2011-05-04)

 * Updated Rakefile to run tests under ruby 1.8.7 and ruby 1.9.2
 * Added `page_size` parameter to `total_pages_in` to allow for checking what if values in that scenario
 * Added `page_size` parameter to `leaders` and `around_me` calls

## 1.0.4 (2011-04-26)

 * Minor bug fix

## 1.0.3 (2011-04-26)

 * Fixing issue using total_pages in leaderboard_in call
 * Internal `massage_leader_data` method will now respect `with_scores`

## 1.0.2 (2011-02-25)

 * Adding `XXX_to`, `XXX_for`, `XXX_in` and `XXX_from` methods that will allow you to set the leaderboard name to interact with outside of creating a new object
 * Added `merge_leaderboards(destination, keys, options = {:aggregate => :min})` method to merge leaderboards given by keys with this leaderboard into destination
 * Added `intersect_leaderboards(destination, keys, options = {:aggregate => :min})` method to intersect leaderboards given by keys with this leaderboard into destination

## 1.0.1 (2011-02-16)

 * `redis_options` can be passed in the initializer to pass options for the connection to Redis
 * `page_size` is now settable outside of the initializer
 * `check_member?(member)`: Check to see whether member is in the leaderboard
 * `score_and_rank_for(member, use_zero_index_for_rank = false)`: Retrieve the score and rank for a member in a single call
 * `remove_members_in_score_range(min_score, max_score)`: Remove members from the leaderboard within a score range

## 1.0.0

 * Initial release

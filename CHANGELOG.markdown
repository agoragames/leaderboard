# leaderboard 1.0.4 (2011-04-26)

 * Minor bug fix

# leaderboard 1.0.3 (2011-04-26)

 * Fixing issue using total_pages in leaderboard_in call
 * Internal `massage_leader_data` method will now respect `with_scores`
 
# leaderboard 1.0.2 (2011-02-25)

 * Adding `XXX_to`, `XXX_for`, `XXX_in` and `XXX_from` methods that will allow you to set the leaderboard name to interact with outside of creating a new object
 * Added `merge_leaderboards(destination, keys, options = {:aggregate => :min})` method to merge leaderboards given by keys with this leaderboard into destination
 * Added `intersect_leaderboards(destination, keys, options = {:aggregate => :min})` method to intersect leaderboards given by keys with this leaderboard into destination

# leaderboard 1.0.1 (2011-02-16)

 * `redis_options` can be passed in the initializer to pass options for the connection to Redis
 * `page_size` is now settable outside of the initializer
 * `check_member?(member)`: Check to see whether member is in the leaderboard
 * `score_and_rank_for(member, use_zero_index_for_rank = false)`: Retrieve the score and rank for a member in a single call
 * `remove_members_in_score_range(min_score, max_score)`: Remove members from the leaderboard within a score range

# leaderboard 1.0.0

 * Initial release

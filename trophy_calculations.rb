# Limits by 10 any collection
def limit_by_10(collection)
    return collection.take(10) if collection.instance_of?(Array)
    collection.all(:limit => 10)
end

# This one returns last games ordered by endtime, with the latest game
# first. Optionally give conditions.
def get_last_games(and_collection=nil)
    params = { :order => [ :endtime.desc ] }
    games = Game.all(params)
    games &= and_collection if !and_collection.nil?
    games
end

# This one returns users ordered by the number of ascensions they have
def most_ascensions_users(and_collection=nil)
    # Now, I couldn't find an effective way to do this in a single SQL
    # query, I'll just collect all ascensions and then work on that. 
    # Should be a manageable amount.
    ascensions = Game.all(:death => 'ascended')
    ascensions &= and_collection if !and_collection.nil?

    # Count the ascensions per user to this hash
    user_ascensions = { }
    accounts_c = { }
    ascensions.each do |game|
        if !accounts_c[game.name].nil? then
          account = accounts_c[game.name]
        else
          account = Account.first(:name => game.name)
          next if account.nil?
          accounts_c[game.name] = account
        end

        next if account.user.nil?

        user = account.user

        user_ascensions[user.login] = 0 if user_ascensions[user.login].nil?
        user_ascensions[user.login] += 1
    end

    user_ascensions.sort_by{|username, ascensions| -ascensions}
end
    
# Helper class for calculating ascension density
class AccountCalc
    attr_accessor :games, :score, :account, :game1, :game2
    def initialize
        @games = [ ]
        @score = 0
    end

    def num_ascensions
        ascensions = 0
        @games.each do |game|
            ascensions += 1 if game.death == 'ascended'
        end
        ascensions
    end

    def calculate_score_between(games, min_score = 0.0)
        final_max = 0.0
        max_so_far = max_ending_here = 0.0
        for asc in games do
            a = asc.death == 'ascended' ? 1.0 : -1.0
            max_ending_here = max_ending_here + a if max_ending_here + a > 0
            max_so_far = max_so_far > max_ending_here ? max_so_far : max_ending_here
        end
        final_max = final_max > max_so_far ? final_max : max_so_far
        final_max
    end

    def calculate_score
        # Calculate the longest distance between ascensions
        # So first ascension and last ascension

        @score = calculate_score_between(@games)
        @score
    end
end


def best_sustained_ascension_rate(and_collection=nil)
    # First step, collect the games.
    accounts = Account.all
    accounts_c = { }
    accounts.each do |account|
        accounts_c[account.name] = AccountCalc.new
        accounts_c[account.name].account = account
        accounts_c[account.name].games = Game.all(:name => account.name,
                                                  :order => [:endtime.desc])
    end

    # Sort the games and calculate score
    accounts_c.each do |account, account_class|
        account_class.calculate_score
    end

    users = { }
    # Wrap the thing up to users.
    accounts_c.each do |account, account_class|
        users[account_class.account.user.login] = { } if
            users[account_class.account.user.login].nil?
        u = users[account_class.account.user.login]
        if u[:score].nil? or u[:score] < account_class.score then
            u[:score] = account_class.score
            u[:game1] = account_class.game1
            u[:game2] = account_class.game2
        end
    end

    users.sort_by{|username, info| -info[:score]}
end

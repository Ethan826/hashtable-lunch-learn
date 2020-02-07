# frozen_string_literal: true

# Monkey patch `blank?` convenience method.
class Object
  # Ported from Rails
  def blank?
    respond_to?(:empty?) ? !!empty? : !self
  end
end

# Implements a HashTable using open addressing and Robin Hood hashing.
class HashTable
  attr_reader :count

  # Construct a new instance of HashTable.
  #
  # @param size [number] The initial size of the HashTable.
  def initialize(size = DEFAULT_HASHTABLE_SIZE)
    @table = Array.new(size)
    @count = EMPTY_COUNT
  end

  # Insert a value into the HashTable, returning whether the value was
  # inserted.
  #
  # @param value [any] The value to insert.
  # @return [boolean] Whether that value was inserted.
  def insert(value) # rubocop:disable Metrics/MethodLength
    puts "I want to insert #{value}"
    initial_value = value
    starting_bucket = bucket = compute_bucket(value)
    puts "I want to put it in bucket #{bucket}"

    loop do
      contents = table[bucket]

      if contents == initial_value # This value is already in the HashTable
        puts "#{contents} is already in bucket #{bucket}: stopping"
        break false
      elsif contents.blank? # This is an available spot.
        puts "Looks like bucket #{bucket} is empty. Let's put it there."
        insert_into_bucket(value, bucket)
        break true
      else # We need to keep searching for a spot.
        puts "Bucket #{bucket} has value #{contents}. Need to keep looking."
        value = swap_if_needed(value, bucket)

        bucket = increment_bucket(bucket)
        raise LOOPED_MESSAGE if bucket == starting_bucket
      end
    end
  end

  # Whether the HashTable contains a particular value.
  #
  # @param value [any] The value to query for.
  # @return [boolean] Whether the HashTable contains `value`.
  def include?(value)
    bucket = compute_adjusted_bucket(value)
    table[bucket] == value
  end

  # Delete a value from the HashTable, returning whether the value was deleted.
  #
  # @param value [any] The value to delete.
  # @return [boolean] Whether the value was deleted.
  def delete(value)
    puts "I want to delete #{value}"

    bucket = compute_adjusted_bucket(value)
    puts "It's in #{bucket} bucket if it's anywhere."

    contains_value = @table[bucket] == value
    puts "It #{contains_value ? 'is' : 'isn\'t'} there"
    @table[bucket] = TOMBSTONE_MARKER if contains_value
    puts "Put #{TOMBSTONE_MARKER}"

    contains_value
  end

  protected

  def dump_table
    table
  end

  private

  DEFAULT_GROWTH_MULTIPLE = 2
  DEFAULT_HASHTABLE_SIZE = 16
  EMPTY_COUNT = 0
  LOOPED_MESSAGE = "Looped through buckets (infinite loop)"
  MAX_LOAD_FACTOR = 0.75
  TOMBSTONE_MARKER = :tombstone

  attr_reader :table

  # Compute the "correct" bucket, meaning the bucket where the value belongs
  # absent collisions.
  #
  # @return [nubmer] The bucket number.
  def compute_bucket(value, size = table.length)
    value.hash % size
  end

  # Given a bucket number, increment it, handling wrapping.
  #
  # @param bucket [number] The bucket number to increment.
  # @return [number] The next bucket after `bucket`, possibly wrapped to the
  #   beginning of the HashTable.
  def increment_bucket(bucket)
    (bucket + 1) % table.length
  end

  # Go to the bucket that should contain the value. If the value is already in
  # the HashTable, go there. If the HashTable doesn't contain the value, go to
  # the first blank spot after the value.
  #
  # @returns [number] The bucket number containing the value or the first empty
  #   empty bucket after the "correct" bucket.
  def compute_adjusted_bucket(value)
    ideal_bucket = bucket = compute_bucket(value)
    until table[bucket].yield_self { |val| val.blank? || val == value }
      bucket = increment_bucket(bucket)
      raise LOOPED_MESSAGE if bucket == ideal_bucket
    end

    bucket
  end

  # Decide whether the HashTable needs to be rehashed because it exceeds its
  # maximum load factor. If it does need to be rehashed, rehash.
  def maybe_rehash
    load_factor = (count / table.length.to_f)
    puts "Thinking about rehashing. Load factor is #{load_factor}"

    rehash if load_factor > MAX_LOAD_FACTOR
  end

  # Rehash the array after growing it by `growth_multiple`.
  #
  # The multiple by which to grow the current size of the HashTable.
  def rehash(growth_multiple = DEFAULT_GROWTH_MULTIPLE)
    puts "Rehashing"
    new_size = (table.length * growth_multiple).to_i
    @table = table.each_with_object(HashTable.new(new_size)) do |value, result|
      result.insert(value) unless value == TOMBSTONE_MARKER
    end.dump_table
  end

  # Insert a value into a bucket, updating the item count and rehashing as
  # needed.
  #
  # @param value [any] The value to insert.
  # @param bucket [number] The bucket into which to insert the value.
  def insert_into_bucket(value, bucket)
    @table[bucket] = value
    @count += 1
    maybe_rehash
  end

  # Implement the Robin Hood strategy: Given a value and bucket, determine
  # whether it is the value that is more out of place, or the current content
  # of the bucket that is more out of place. If the current content of the
  # bucket is more out of place, swap that with the value. Return whichever
  # value still needs a bucket.
  #
  # @param value [any] The value to consider swapping with the current content
  #   of the bucket.
  # @param bucket [any] The bucket.
  # @return [any] Whichever data isn't in the bucket after considering a swap.
  def swap_if_needed(value, bucket)
    return value if table[bucket] == TOMBSTONE_MARKER

    if amount_displaced(value, bucket) < amount_displaced(table[bucket], bucket)
      puts "Doing Robin Hood swapping."
      value, table[bucket] = table[bucket], value
    end

    value
  end

  # Determine how far a value is displaced from its ideal bucket, considering
  # the possibility of wrapping around the HashTable.
  #
  # @param value [any] The value in the specified bucket
  # @param bucket [number] The bucket number
  # @return [number] How many places displaced
  def amount_displaced(value, bucket)
    correct_bucket = compute_bucket(value)

    if correct_bucket < bucket # We didn't wrap
      bucket - correct_bucket
    else                       # We did wrap
      table.length - correct_bucket + bucket
    end
  end
end

h = HashTable.new(3)
require "pry"; binding.pry
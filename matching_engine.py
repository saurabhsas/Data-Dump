from typing import List
from collections import Counter

def topKFrequent(nums: List[int], k: int) -> List[int]:

    # Step 1: Count frequency of each number
    count = Counter(nums)

    # Step 2: Create buckets
    # Index = frequency
    buckets = [[] for _ in range(len(nums) + 1)]

    # Step 3: Put numbers into buckets
    for num, freq in count.items():
        buckets[freq].append(num)

    # Step 4: Collect top k frequent elements
    result = []

    # Traverse buckets from high frequency to low
    for freq in range(len(buckets) - 1, 0, -1):

        for num in buckets[freq]:
            result.append(num)

            if len(result) == k:
                return result

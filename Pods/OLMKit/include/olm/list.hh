/* Copyright 2015 OpenMarket Ltd
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
#ifndef OLM_LIST_HH_
#define OLM_LIST_HH_

#include <cstddef>

namespace olm {

template<typename T, std::size_t max_size>
class List {
public:
    List() : _end(_data) {}

    typedef T * iterator;
    typedef T const * const_iterator;

    T * begin() { return _data; }
    T * end() { return _end; }
    T const * begin() const { return _data; }
    T const * end() const { return _end; }

    /**
     * Is the list empty?
     */
    bool empty() const { return _end == _data; }

    /**
     * The number of items in the list.
     */
    std::size_t size() const { return _end - _data; }

    T & operator[](std::size_t index) { return _data[index]; }

    T const & operator[](std::size_t index) const { return _data[index]; }

    /**
     * Erase the item from the list at the given position.
     */
    void erase(T * pos) {
        --_end;
        while (pos != _end) {
            *pos = *(pos + 1);
            ++pos;
        }
    }

    /**
     * Make space for an item in the list at a given position.
     * If inserting the item makes the list longer than max_size then
     * the end of the list is discarded.
     * Returns the where the item is inserted.
     */
    T * insert(T * pos) {
        if (_end != _data + max_size) {
            ++_end;
        } else if (pos == _end) {
            --pos;
        }
        T * tmp = _end - 1;
        while (tmp != pos) {
            *tmp = *(tmp - 1);
            --tmp;
        }
        return pos;
    }

    /**
     * Make space for an item in the list at the start of the list
     */
    T * insert() { return insert(begin()); }

    /**
     * Insert an item into the list at a given position.
     * If inserting the item makes the list longer than max_size then
     * the end of the list is discarded.
     * Returns the where the item is inserted.
     */
    T * insert(T * pos, T const & value) {
        pos = insert(pos);
        *pos = value;
        return pos;
    }

    List<T, max_size> & operator=(List<T, max_size> const & other) {
        if (this == &other) {
            return *this;
        }
        T * this_pos = _data;
        T * const other_pos = other._data;
        while (other_pos != other._end) {
            *this_pos = *other;
            ++this_pos;
            ++other_pos;
        }
        _end = this_pos;
        return *this;
    }

private:
    T * _end;
    T _data[max_size];
};

} // namespace olm

#endif /* OLM_LIST_HH_ */

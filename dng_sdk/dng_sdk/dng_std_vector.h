#ifndef DNG_STD_VECTOR_H
#define DNG_STD_VECTOR_H

/*****************************************************************************/

#include "dng_std_types.h"

/*****************************************************************************/

/// \brief A wrapper around std::vector for DNG SDK use
template<typename T>
class dng_std_vector {
public:
    using value_type = T;
    using iterator = typename dng_std::vector<T>::iterator;
    using const_iterator = typename dng_std::vector<T>::const_iterator;
    using size_type = typename dng_std::vector<T>::size_type;

    dng_std_vector() = default;
    
    explicit dng_std_vector(size_type count) : data_(count) {}
    
    dng_std_vector(size_type count, const T& value) : data_(count, value) {}
    
    template<typename InputIt>
    dng_std_vector(InputIt first, InputIt last) : data_(first, last) {}
    
    dng_std_vector(const dng_std_vector& other) = default;
    dng_std_vector(dng_std_vector&& other) noexcept = default;
    
    dng_std_vector& operator=(const dng_std_vector& other) = default;
    dng_std_vector& operator=(dng_std_vector&& other) noexcept = default;
    
    ~dng_std_vector() = default;

    // Element access
    T& operator[](size_type pos) { return data_[pos]; }
    const T& operator[](size_type pos) const { return data_[pos]; }
    
    T& at(size_type pos) { return data_.at(pos); }
    const T& at(size_type pos) const { return data_.at(pos); }
    
    T& front() { return data_.front(); }
    const T& front() const { return data_.front(); }
    
    T& back() { return data_.back(); }
    const T& back() const { return data_.back(); }
    
    T* data() noexcept { return data_.data(); }
    const T* data() const noexcept { return data_.data(); }

    // Iterators
    iterator begin() noexcept { return data_.begin(); }
    const_iterator begin() const noexcept { return data_.begin(); }
    const_iterator cbegin() const noexcept { return data_.cbegin(); }
    
    iterator end() noexcept { return data_.end(); }
    const_iterator end() const noexcept { return data_.end(); }
    const_iterator cend() const noexcept { return data_.cend(); }

    // Capacity
    bool empty() const noexcept { return data_.empty(); }
    size_type size() const noexcept { return data_.size(); }
    size_type max_size() const noexcept { return data_.max_size(); }
    void reserve(size_type new_cap) { data_.reserve(new_cap); }
    size_type capacity() const noexcept { return data_.capacity(); }
    void shrink_to_fit() { data_.shrink_to_fit(); }

    // Modifiers
    void clear() noexcept { data_.clear(); }
    
    iterator insert(const_iterator pos, const T& value) {
        return data_.insert(pos, value);
    }
    
    iterator insert(const_iterator pos, T&& value) {
        return data_.insert(pos, std::move(value));
    }
    
    iterator insert(const_iterator pos, size_type count, const T& value) {
        return data_.insert(pos, count, value);
    }
    
    template<typename InputIt>
    iterator insert(const_iterator pos, InputIt first, InputIt last) {
        return data_.insert(pos, first, last);
    }
    
    iterator erase(const_iterator pos) {
        return data_.erase(pos);
    }
    
    iterator erase(const_iterator first, const_iterator last) {
        return data_.erase(first, last);
    }
    
    void push_back(const T& value) {
        data_.push_back(value);
    }
    
    void push_back(T&& value) {
        data_.push_back(std::move(value));
    }
    
    void pop_back() {
        data_.pop_back();
    }
    
    void resize(size_type count) {
        data_.resize(count);
    }
    
    void resize(size_type count, const T& value) {
        data_.resize(count, value);
    }
    
    void swap(dng_std_vector& other) noexcept {
        data_.swap(other.data_);
    }

    // Comparison operators
    bool operator==(const dng_std_vector& other) const {
        return data_ == other.data_;
    }

    bool operator!=(const dng_std_vector& other) const {
        return !(*this == other);
    }

private:
    dng_std::vector<T> data_;
};

/*****************************************************************************/

#endif  // DNG_STD_VECTOR_H 
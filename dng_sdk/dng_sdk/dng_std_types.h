#ifndef DNG_STD_TYPES_H
#define DNG_STD_TYPES_H

/*****************************************************************************/

#include <vector>
#include <memory>
#include <algorithm>

/*****************************************************************************/

namespace dng_std {

template<typename T>
using vector = std::vector<T>;

template<typename T>
using shared_ptr = std::shared_ptr<T>;

} // namespace dng_std

/*****************************************************************************/

#endif  // DNG_STD_TYPES_H 
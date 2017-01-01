---
title: Python装饰器
date: 2017-01-01 12:02:55
tags: 装饰器
categories: python
---
Python装饰器是个不错的东西，应用场景也比较广泛。
之前写过一个Saltstack的模块，用于查询我们的CMDB。查询操作可能会由于网络抖动等原因失败，如果查询失败，会再次进行尝试，设定它会尝试三次。
这个装饰器的一个典型应用场景，而且这个装饰器还带参数。之前没怎么用过待参数的装饰器，虽然技术含量也不高，还是记录一下。
```python
import logging
from functools import wraps
from requests.exceptions import RequestException, Timeout, HTTPError

log = logging.getLogger(__name__)

def retry(times, *exception_types):
    def outer(func):
        @wraps(func)
        def inner(*args, **kwargs):
            for n in range(times):
                try:
                    return func(*args, **kwargs)
                except RequestException:
                    continue
        return inner
    return outer


class QueryCMDB:
    ...

    @retry(3, Timeout, HTTPError)
    def _get_data(self, page, size, timeout, **q_args):
        ...
        url = self.url_concat(...)

        log.info('url: {}'.format(url))
        with self.session as s:
            resp = s.get(url, headers=self.xheaders(...), timeout=timeout)
        return resp.json()

    def query(self, fields=None, timeout=None, page=1, size=50, **kwargs):
        data = self._get_data(page=page, size=size, timeout=timeout, **kwargs)
        if data:
            pass

client = QueryCMDB(...)
```

调用client查询CMDB：
```python
def get(schema, fields=None, timeout=1, **kwargs):
    """
    用法示例：
    salt-call cmdb2.get switch fields="swid sn" sn="xxxxxxx"

    fields支持写法：['swid', 'sn']，可以用于sls文件中定义。
    """

    pass
```
我们的CMDB使用ES存储数据。这个自定义模块从CMDB中取出数据，并过滤指定的fields的值，kwargs里可以更加详细的指定查询条件。
对于我的这个模块而言，捕获的是RequestException，Timout和HTTPError都是它的子类，所以直接在里面写死了，所以不是很通用，但是可以很容易的进行抽象一下，提炼成更通用的装饰器。
就这样。
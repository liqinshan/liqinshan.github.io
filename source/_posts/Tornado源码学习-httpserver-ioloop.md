---
title: 'Tornado源码学习: httpserver & ioloop'
date: 2017-01-01 00:27:22
tags: tornado
categories: python
---
看了看Tornado源码，读到HTTPServer和IOLoop这里，发现逻辑还是比较复杂的，直接看有点晕。还是先看看早期版本，还可以看看Tornado一路过来的脉络。

<!-- more -->

### 一、Tornado 1.0以前
tornado的早期版本中（1.0之前），httpserver在初始化的时候创建ioloop实例，listen的时候创建socket对象，并由ioloop实例调用其add_handler()方法为该socket的指定事件注册处理器。
HTTPServer模块的简化代码：
```python
class HTTPServer(object):
    # 初始化HTTPServer，创建ioloop实例
    def __init__(self, request_callback, io_loop=None):
        self.request_callback = request_callback
        self.io_loop = io_loop or ioloop.IOLoop.instance()
        self._socket = None

    # 在指定端口上创建socket，并由ioloop调用其add_handler()方法为socket的指定事件注册处理器
    # add_handler()监听socket上的READ事件，事件发生的时候调用 _handle_events 进行处理
    def listen(self, port):
        assert not self._socket
        self._socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM, 0)
        self._socket.bind("", port)
        self._socket.listen(128)
        self.io_loop.add_handler(self._socket.fileno(), self._handle_events, self.ioloop.READ)

    # socket的处理器
    def _handle_events(self, fd, events):
        while True:
            try:
                connection, address = self._socket.accept()
            except socket.error, e:
                if e[0] in (errno.EWOULDBLOCK, errno.EAGAIN):
                    return
                raise

            try:
                # 调用IOStream包装socket，并在HTTPConnection中进行真正的HTTP逻辑处理
                stream = iostream.IOStream(connection, io_loop=self.io_loop)
                HTTPConnection(stream, address, self.request_callback)
            except:
                logging.error('')
```

#### socket
socket起源于UNIX。UNIX下一切皆文件，服务器（被动连接方）和客户端（主动链接方）各自维护一个“文件”（TCP栈缓冲区），在建立连接后，可以向各自的文件写入内容供对方读取，或读取对方内容，通讯结束后关闭文件。
交互流程大概是这个样子：
[图片占位，回头补]

socket对象也是模拟这个过程进行工作：
```python
s = socket.socket()   # 创建socket
s.bind()     # 绑定端口
s.listen()   # 进行监听
```
服务器端要能够同时响应多个连接请求，所以它必须
1）能够标记客户端
2）能够为每一个客户端连接创建一个新的socket对象用于响应请求
在具体的实践中，一般是起一个while循环，在循环里accpet客户端的连接，accept的时候创建一个新的socket：
```python
while True:
     #创建socket对象conn
     conn, addr = s.accept()

     #处理socket对象conn
     try:
        pass
     except:
        pass
```

#### ioloop
ioloop的实例化以及socket监听：
```python
self.io_loop = io_loop or ioloop.IOLoop.instance()
self.io_loop.add_handler(self._socket.fileno(),self._handle_events,self.io_loop.READ)
```
HTTPServer初始化的时候取出或创建一个ioloop实例，ioloop实例定义了add_handler()、update_handler()、remove_handler()三个函数为socket的指定事件添加相应的处理器，并使用add_callback()来调度下一次的IO循环上的callback，使用add_timeout()来调度基于时间的事件，在ioloop的指定时间点上执行callback。
```python
class IOLoop(object):
     # 初始化，选择恰当的事件循环机制，但ioloop的实例并不在初始化的时候创建！
     # 默认的事件循环机制为select或epoll其中的一种，选择时会首先尝试epoll
     # IOLoop中维护了四个数据结构：_handlers，_events，_callbacks, _timeouts
     def __init__(self, impl=None):
          self._impl = impl or _poll()
          self._handlers = {}
          self._events = {}
          self._callbacks = set()
          self._timeouts = []
          self._running = False

     # 创建一个全局的ioloop实例。单例。
     @classmethod
     def instance(cls):
          if not hasattr(cls, ‘_instance’):
               cls._instance = cls()
          return cls._instance

     # 为socket上指定的事件注册一个handler
     # Tornado中，IO事件有三种：READ/WRITE/ERROR
     def add_handler(self, fd, handler, events):
          self._handlers[fd] = handler
          self._impl.register(fd, events | self.ERROR)

     # 在下一次的ioloop循环中执行指定的callback
     def add_callback(self, callback):
          self._callbacks.add(callback)
          self._wake

     # Tornado中，ioloop除了可以响应IO事件外，还可以调度基于时间的事件。
     # 官方文档中称，add_timeout()是time.sleep()的非阻塞版本。它在ioloop的某个时间点上执行指定的callback。
     def add_timeout(self, deadline, callback):
          timeout = _Timeout(deadline, callback)
          bisect.insort(self._timeouts,  timeout)
          return timeout

     def _run_callback(self, callback):
          try:
               callback()
          except (KeyboardInterrupt, SystemExit):
               raise
          except:
               logging.error(‘Exception in callback %s’, callback, exc_info=True)

     def start(self):
          # 开始ioloop循环，处理各种callback
          pass

# 创建数据结构，保存timeout事件
class _Timeout(object):
     def __init__(self, deadline, callback):
          self.deadline = deadline
          self.callback = callback

     def __cmp__(self, other):
          return cmp((self.deadline, id(self.callback)), (other.deadline, id(other.callback)))

# 为epoll实现register等方法
class _EPoll(object):
     def __init__(self):
          pass
     def register(self, fd, events):
          pass

# 为select实现register等方法
class _Select(object):
     def __init__(self):
          pass
     def register(self, fd, events):
          pass

# 选择系统的事件循环机制
if hasattr(select, ‘epoll’):
     _poll = select.epoll
else:
     try:
          import epoll
          _poll = _EPoll
     except:
          import sys
          _poll = _Select
```

#### iostream
ioloop实例调用add_handler，为socket的指定事件注册了一个处理器： _handle_events()。
_handle_events这个处理器中，为每一个HTTP连接创建一个socket，然后创建一个iostream对象来操作（读写）该socket。Tornado把iostream的操作包装进了HTTPConnection，在HTTPConnection中处理该HTTP连接的header，body等。
```python
class IOStream(object):
     # 把socket传入进来，为其封装一个iostream对象，通过iostream对象来操作socket
     def __init__(self, socket, io_loop=None):
          self.socket = socket
          self._read_buffer = ''
          self._write_buffer = ''
          self._read_bytes = None
          self.io_loop = io_loop or ioloop.IOLoop.instance()
          self._state = self.io_loop.ERROR
          # 添加处理器，在ioloop上监听socket事件
          self.io_loop.add_handler(self.socket.fileno(), self._handle_events, self._state)

     # 一旦socket就绪，ioloop根据不同的事件，来调度不同的处理器进行socket的read/write操作
     def _handle_events(self, fd, events):
          if not self.socket:
               logging.warnning(‘Got events for closed stream %d’, fd)
               return
          if events & self.io_loop.READ:
               self._handle_read()
          if not self.socket:
               return
          if events & self.io_loop.WRITE:
               self._handle_write()
          if not self.socket:
               return
          if events & self.io_loop.ERROR:
               self.close()
               return

          state = self.io_loop.ERROR

          if self._read_delimiter or self._ready_bytes:
               state |= self.io_loop.READ
          if self._write_buffer:
               state |= self.io_loop.WRITE
          if state != self._state:
               self._state = state
               self.io_loop.update_handler(self.socket.fileno(), self._state)
     
     # 进入处理流程
     def _handle_read(self):
        try:
            chunk = self.socket.recv(self.read_chunk_size)
        except socket.error, e:
            self.close()
            return
        
        if not chunk:
            self.close()
            return
        
        # 把从socket中读到的数据写入缓冲区
        self._read_buffer += chunk
        
        # 执行回调，消费缓冲区中的数据
        if self._read_bytes:
            self._run_callback(callback, self._consume(num_bytes))
        elif self._read_delimiter:
            self._run_callback(callback, self._consume(loc+delimiter_len))
```

#### HTTPConnection
ioloop中，接受一个socket，为其创建iostream对象，然后把iostream对象传入HTTPConnection，由HTTPConnection对象来操作iostream对象。
底层的是socket；其上层是iostream对象，它对socket的操作进行了封装；再上层是HTTPConnection，由它来处理iostream对象。
```python
class HTTPConnection(object):
     def __init__(self, stream, address, request_callback):
          self.stream = stream
          self.address = address
          self.request_callback = request_callback
          self._request = None
          self._request_finished = False
          self.stream.read_until(‘\r\n\r\n’, self._on_headers)

     # 把数据（chunk）写入该stream，数据写入完毕，执行callback函数 _on_write_complete
     def write(self, chunk):
          assert self._request, 'Request closed'
          self.stream.write(chunk, self._on_write_complete)
```

### 二、1.0版本中的新变化
#### HTTPServer模块中重构了listen()方法
函数应该尽可能的功能单一，所以函数体一般要足够小，功能复杂的函数可以进行拆解成几个函数。HTTPServer中的listen()拆解成了bind()和start()两个函数。
```python
def listen(self, port, address=''):
    self.bind(port, address)
    self.start(1)
```
跟socket有关的部分拆分到了bind()方法中，socket处理器注册的部分拆分到了start()方法中，并进行了功能扩充：
```python
def bind(self, port, address=''):
     pass

# 功能扩充，支持多进程。默认使用单进程。
def start(self, num_processes=1):
     # 若传入的处理器数不合法（None或小于等于0），获取服务器的处理器数
     if num_processes is None or num_process <= 0:
          try:
               num_processes = os.sysconf('SC_NPROCESSORS_CONF')
          except ValueError:
               num_processes = 1

     # 若处理器数大于1，判断ioloop实例是否已被创建
     if num_processes > 1 and ioloop.IOLoop.initialized():
          num_processes = 1

     # fork出num_processes个子进程，为每一个子进程创建一个ioloop实例
     if num_processes > 1:
          for i in range(num_processes):
               if os.fork() == 0:
                    self.ioloop = ioloop.IOLoop.instance()
                    self.ioloop.add_handler(...)
                    return
          os.waitpid(-1, 0)
     else:
          if not self.ioloop:
               self.ioloop = ioloop.IOLoop.instance()
          self.ioloop.add_handler(...)
```

#### ioloop中新增了PeriodicCallback
该类用于周期性的调度某些任务。最开始的目的应该是支持autoreload，当Tornado的某个模块被修改时，自动重启ioloop实例：
```python
class PeriodicCallback(object):
     def __init__(callback, callback_time, io_loop=None):
          self.callback = callback
          self.callback_time = callback_time
          self.io_loop = io_loop or IOLoop.instance()
          self._running = True

     def start(self):
          timeout = time.time() + self.callback_time / 1000.0
          self.io_loop.add_timeout(timeout, self._run)

     def _run(self):
          if not self._running; return
          try:
               self.callback()
          except (KeyboardInput, SystemExit):
               raise
          except:
               logging.error(‘Error in periodic callback’, exc_info=True)

          self.start()
```

ioloop中对它的调度：
```python
class IOLoop(object):
     # 初始化的时候，_timeouts为空列表
     def __init__(self, ipml=None):
          self._timeouts = []

     # 启动ioloop
     def start(self):
          # ioloop进入死循环
          while True:
               poll_timeout = 0.2

               # 检查 _callbacks 中是否有数据写入，并进入处理流程
               callbacks = list(self._callbacks)
               for callback in callbacks:
                    pass

               # 检查 _timeouts 中是否有数据写入，计算时间戳并比较，若过期则执行callback
               if self._timeouts:
                    now = time.time()
                    while self._timeouts and self._timeouts[0].deadline <= now:
                         timeout = self._timeouts.pop(0)
                         self._run_callback(timeout.callback)
                    if self._timeouts:
                         milliseconds = self._timeouts[0].deadline - now
                         poll_timeouts = min(milliseconds, poll_timeout)
```

autoreload是如何调用PeriodicCallback的：
```python
def start(io_loop=None, check_time=500):
     io_loop = io_loop or ioloop.IOLoop.instance()
     modify_times = {}
     callback = functools.partial(_reload_on_update, io_loop, modify_times)
     scheduler = ioloop.PeriodicCallback(callback, check_time, io_loop=io_loop)
     scheduler.start()
```

某些定时执行的任务，我们也可以直接使用它来完成。下面这个示例，每2秒钟打印一次字符串 ‘something’：
```python
def print_something():
    print('something')
   
def main():
    # 添加周期性任务到当前的ioloop
    ioloop.PeriodicCallback(print_something, 2000).start()
    # 启动ioloop
    ioloop.IOLoop.instance().start()

if __name__ == '__main__':
    main()
```

### 三、Tornado 2.0
2.0中，IOStream使用双端队列对象（deque）来缓冲从socket中读取到的数据，不再使用字符串拼接的方式。性能上是一个大的提升。
```python
class IOStream(object):
    def __init__(self):
        # 改用用双端队列来缓存数据
        self._read_buffer = collections.deque()
        self._write_buffer = collections.deque()
        self._read_bytes = None
        
    # 相比之前的版本，Tornado对这个函数进行了拆分，这里只处理逻辑，而数据处理工作拆分了出去。
    # 从socket中读取数据并缓冲，调用函数_read_to_buffer()来完成；消费缓冲中的数据，调用_read_from_buffer()来完成
    def _handle_read(self):
        # 开启死循环从socket中读取数据
        while True:
            try:
                # 缓存从socket中读取到的数据
                result = self._read_to_buffer()
            except Exception:
                self.close()
                return
            
            if result = 0:
                break
            else:
                # 消费缓存中的数据
                if self._read_from_buffer():
                    return
                
    def _read_to_buffer(self):
        try:
            chunk = self._read_from_socket()
        except socket.error, e:
            self.close()
            raise
            
        if chunk is None:
            return 0
        
        # 把读取到的数据添加到队列末尾
        self._read_buffer.append(chunk)
        self._read_buffer_size += len(chunk)
        if self._read_buffer_size >= self.max_buffer_size:
            pass
        
        return len(chunk)
        
    # 读取缓冲区中的数据并消费。读取方式有两种：按大小来读取，以及按分隔符来读取
    def _read_from_buffer(self):
        if self._read_bytes:
            if self._read_buffer_size >= self._read_bytes:
                num_bytes = self._read_bytes
                callback = self._read_callback
                self._read_callback = None
                self._read_bytes = None
                self._run_callback(callback, self._consume(num_bytes))
                return True
        elif self._read_delimiter:
            # 合并缓冲队列的头部
            _merge_prefix(self._read_buffer, sys.maxin)
            loc = self._read_buffer[0].find(self._read_delimiter)
            if loc != -1:
                callback = self._read_callback
                delimiter_len = len(self._read_delimiter)
                self._read_callback = None
                self._read_delimiter = None
                self._run_callback(callback, self._consume(loc+delimiter_len))
                return True
            
        return False
```

\_merge\_prefix(deque, size)
在缓冲数据时，把数据添加到双端队列的尾部，而从缓存中读取数据并消费时，是从头部读取的。那么一次读取多少数据就是个学问了，这个方法可以按照我们的需要，把队列头部的数据组织成合适的大小。

IOStream模块中多次用到这个函数，如_handle_write()：
```python
def _handle_write(self):
    while self._write_buffer:
        try:
            # socket发送数据时，每次发送的数据大小不超过128KB
            if not self._write_buffer_frozen:
                _merge_prefix(self._write_buffer, 128*1024)
            num_bytes = self.socket.send(self._write_buffer[0])
        except socket.error, e:
            self.close()
            return
```

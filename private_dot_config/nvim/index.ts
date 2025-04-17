// 节流函数
const throttle = (fn: Function, delay: number) => {
  let lastTime = 0;
  return function (...args: any[]) {
    const now = Date.now();
    if (now - lastTime >= delay) {
      fn.apply(this, args);
      lastTime = now;
    }
  };
};
// 节流函数的使用示例
const log = () => {
  console.log("Function executed!");
};

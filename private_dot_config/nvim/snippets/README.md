# Neovim Snippets 快速参考表

## 📘 React Hooks (javascriptreact) - `r` 前缀

| Prefix  | 功能               | 说明         |
| ------- | ------------------ | ------------ |
| `ruse`  | useEffect Hook     | 带依赖数组   |
| `ruee`  | useEffect Empty    | 空依赖数组   |
| `rust`  | useState Hook      | React state  |
| `rucb`  | useCallback Hook   | 缓存回调     |
| `rum`   | useMemo Hook       | 缓存计算     |
| `rur`   | useRef Hook        | 引用         |
| `ructx` | useContext Hook    | 上下文       |
| `rch`   | Custom Hook        | 自定义钩子   |
| `rcond` | Conditional Render | && 条件渲染  |
| `rtern` | Ternary Render     | ? : 三元渲染 |
| `rmap`  | Array Map          | 数组映射     |
| `jsx`   | JSX Snippet        | JSX 元素     |
| `jsxc`  | Self-closing JSX   | 自闭合组件   |
| `rexp`  | Export Component   | 导出组件     |

---

## 🔷 TypeScript React (typescriptreact) - `tr` 前缀

| Prefix  | 功能              | 说明              |
| ------- | ----------------- | ----------------- |
| `trfc`  | FC Component      | 完整组件模板      |
| `trfcs` | FC Simple         | 简化组件模板      |
| `trcp`  | Component Props   | 带 Props 接口     |
| `trust` | useState TS       | 带类型的 useState |
| `trur`  | useRef TS         | 带类型的 useRef   |
| `trcg`  | Generic Component | 泛型组件          |

---

## 🔹 TypeScript Utils (typescript) - `ts` 前缀

| Prefix     | 功能           | 说明         |
| ---------- | -------------- | ------------ |
| `tsintf`   | Interface      | 接口定义     |
| `tstype`   | Type           | 类型别名     |
| `tsenum`   | Enum           | 枚举         |
| `tsclass`  | Class          | 类定义       |
| `tsgenfn`  | Generic Fn     | 泛型函数     |
| `tsgent`   | Generic Type   | 泛型类型     |
| `tsasync`  | Async Fn       | 异步函数     |
| `tstry`    | Try-Catch      | 异常处理     |
| `tsprom`   | Promise        | Promise 包装 |
| `tsarrow`  | Arrow Fn       | 箭头函数     |
| `tsdobj`   | Destruct Obj   | 对象解构     |
| `tsdarray` | Destruct Arr   | 数组解构     |
| `tsspread` | Spread         | 扩展运算符   |
| `tsopt`    | Optional       | 可选属性     |
| `tsro`     | Readonly       | 只读属性     |
| `tsnc`     | Null Coal      | 空值合并     |
| `tsoc`     | Optional Chain | 可选链       |
| `tsunion`  | Union Type     | 联合类型     |
| `tsinter`  | Intersection   | 交叉类型     |

---

## 🟠 React Native (react-native) - `rn` 前缀

| Prefix     | 功能              | 说明         |
| ---------- | ----------------- | ------------ |
| `rnscr`    | Screen            | 屏幕组件     |
| `rnv`      | View              | View 容器    |
| `rnt`      | Text              | Text 组件    |
| `rntouch`  | TouchableOpacity  | 可触摸组件   |
| `rnlist`   | FlatList          | 列表组件     |
| `rnscroll` | ScrollView        | 滚动容器     |
| `rnin`     | TextInput         | 输入框       |
| `rnstyle`  | StyleSheet        | 样式定义     |
| `rnst`     | useState          | State 钩子   |
| `rnef`     | useEffect         | Effect 钩子  |
| `rnimg`    | Image             | 图片组件     |
| `rnload`   | ActivityIndicator | 加载动画     |
| `rnmod`    | Modal             | 模态框       |
| `rnalert`  | Alert             | 弹窗         |
| `rnnav`    | Navigate          | 页面导航     |
| `rnroute`  | useRoute          | 获取路由参数 |

---

## 📝 Markdown (markdown) - 保持简洁

| Prefix                    | 功能               |
| ------------------------- | ------------------ |
| `h1`, `h2`, `h3`          | 标题               |
| `b`, `i`                  | 粗体、斜体         |
| `link`, `img`             | 链接、图片         |
| `code`, `codeblock`       | 代码               |
| `li`, `ol`                | 列表               |
| `quote`, `hr`             | 引用、分割线       |
| `table`, `strike`, `task` | 表格、删除线、任务 |
| `w`                       | 工时               |

---

## 📊 Prefix 分类速查

### 按首字母查找

**r 开头** (React Hooks & Components)

-   基础: `rust`, `ruse`, `ruee`, `rucb`, `rum`, `rur`, `ructx`
-   钩子: `rch` (custom hook)
-   渲染: `rcond`, `rtern`, `rmap`, `rexp`
-   JSX: `jsx`, `jsxc`

**tr 开头** (TypeScript React)

-   组件: `trfc`, `trfcs`, `trcp`, `trcg`
-   钩子: `trust`, `trur`

**ts 开头** (TypeScript)

-   类型: `tsintf`, `tstype`, `tsenum`, `tsclass`
-   泛型: `tsgenfn`, `tsgent`
-   异步: `tsasync`, `tstry`, `tsprom`
-   函数: `tsarrow`
-   解构: `tsdobj`, `tsdarray`
-   运算符: `tsspread`, `tsopt`, `tsro`, `tsnc`, `tsoc`, `tsunion`, `tsinter`

**rn 开头** (React Native)

-   组件: `rnscr`, `rnv`, `rnt`, `rntouch`, `rnlist`, `rnscroll`, `rnin`, `rnimg`, `rnmod`
-   功能: `rnstyle`, `rnst`, `rnef`, `rnload`, `rnalert`, `rnnav`, `rnroute`

---

## 💡 使用技巧

1. **快速触发**: 在编辑器中输入 prefix，通常 Tab 键触发展开
2. **模糊搜索**: 大多数编辑器支持模糊匹配，如输入 `ruf` 可匹配 `trfcs`
3. **占位符**: 按 Tab 在 `$1`, `$2` 占位符间切换
4. **自动命名**: 某些片段支持自动变换，如 `${1/(.)/\\u$1/}` 会自动首字母大写

---

## 📝 文件结构

```
snippets/
├── javascriptreact.json  # React Hooks & JSX
├── typescriptreact.json  # TypeScript + React Components
├── typescript.json       # TypeScript Utilities
├── react-native.json     # React Native Components
├── markdown.json         # Markdown Syntax
└── README.md            # 本文件 - 快速参考表
```

---

## ✨ 特点

-   ✅ 前缀有明确的分类标识（r、tr、ts、rn）
-   ✅ 易于记忆和快速输入
-   ✅ 减少了长前缀，提高了输入效率
-   ✅ 避免了 prefix 重复冲突
-   ✅ 按文件类型合理分配，职责清晰

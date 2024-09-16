return {
  {
    "ibhagwan/fzf-lua",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = function(_, opts)
      opts.winopts = {
        height = 0.90, -- 窗口高度
        width = 0.80, -- 窗口宽度（设置为 1.00 表示全宽）
        row = 0.50, -- 窗口位置（0.50 表示在屏幕中间）
        col = 0.50, -- 窗口居中
        border = "single", -- 窗口边框样式
        preview = {
          layout = "vertical", -- 设置为上下布局
          height = "20", -- 预览窗口高度
        },
      }
    end,
  },
}

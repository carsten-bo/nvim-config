local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')

local clear = helpers.clear
local eq = helpers.eq
local eval = helpers.eval
local exec = helpers.exec
local command = helpers.command
local feed = helpers.feed
local meths = helpers.meths
local assert_alive = helpers.assert_alive

before_each(clear)

describe('WinScrolled', function()
  local win_id

  before_each(function()
    win_id = meths.get_current_win().id
    command(string.format('autocmd WinScrolled %d let g:matched = v:true', win_id))
    command('let g:scrolled = 0')
    command('autocmd WinScrolled * let g:scrolled += 1')
    command([[autocmd WinScrolled * let g:amatch = str2nr(expand('<amatch>'))]])
    command([[autocmd WinScrolled * let g:afile = str2nr(expand('<afile>'))]])
  end)

  after_each(function()
    eq(true, eval('g:matched'))
    eq(win_id, eval('g:amatch'))
    eq(win_id, eval('g:afile'))
  end)

  it('is triggered by scrolling vertically', function()
    local lines = {'123', '123'}
    meths.buf_set_lines(0, 0, -1, true, lines)
    eq(0, eval('g:scrolled'))
    feed('<C-E>')
    eq(1, eval('g:scrolled'))
  end)

  it('is triggered by scrolling horizontally', function()
    command('set nowrap')
    local width = meths.win_get_width(0)
    local line = '123' .. ('*'):rep(width * 2)
    local lines = {line, line}
    meths.buf_set_lines(0, 0, -1, true, lines)
    eq(0, eval('g:scrolled'))
    feed('zl')
    eq(1, eval('g:scrolled'))
  end)

  it('is triggered by horizontal scrolling from cursor move', function()
    command('set nowrap')
    local lines = {'', '', 'Foo'}
    meths.buf_set_lines(0, 0, -1, true, lines)
    meths.win_set_cursor(0, {3, 0})
    eq(0, eval('g:scrolled'))
    feed('zl')
    eq(1, eval('g:scrolled'))
    feed('zl')
    eq(2, eval('g:scrolled'))
    feed('h')
    eq(3, eval('g:scrolled'))
  end)

  it('is triggered by scrolling on a long wrapped line #19968', function()
    local height = meths.win_get_height(0)
    local width = meths.win_get_width(0)
    meths.buf_set_lines(0, 0, -1, true, {('foo'):rep(height * width)})
    meths.win_set_cursor(0, {1, height * width - 1})
    eq(0, eval('g:scrolled'))
    feed('gj')
    eq(1, eval('g:scrolled'))
    feed('0')
    eq(2, eval('g:scrolled'))
    feed('$')
    eq(3, eval('g:scrolled'))
  end)

  it('is triggered when the window scrolls in Insert mode', function()
    local height = meths.win_get_height(0)
    local lines = {}
    for i = 1, height * 2 do
      lines[i] = tostring(i)
    end
    meths.buf_set_lines(0, 0, -1, true, lines)
    feed('L')
    eq(0, eval('g:scrolled'))
    feed('A<CR><Esc>')
    eq(1, eval('g:scrolled'))
  end)
end)

describe('WinScrolled', function()
  -- oldtest: Test_WinScrolled_mouse()
  it('is triggered by mouse scrolling in another window', function()
    local screen = Screen.new(75, 10)
    screen:attach()
    exec([[
      set nowrap scrolloff=0
      set mouse=a
      call setline(1, ['foo']->repeat(32))
      split
      let g:scrolled = 0
      au WinScrolled * let g:scrolled += 1
    ]])

    -- With the upper split focused, send a scroll-down event to the unfocused one.
    meths.input_mouse('wheel', 'down', '', 0, 6, 0)
    eq(1, eval('g:scrolled'))

    -- Again, but this time while we're in insert mode.
    feed('i')
    meths.input_mouse('wheel', 'down', '', 0, 6, 0)
    feed('<Esc>')
    eq(2, eval('g:scrolled'))
  end)

  -- oldtest: Test_WinScrolled_close_curwin()
  it('closing window does not cause use-after-free #13265', function()
    exec([[
      set nowrap scrolloff=0
      call setline(1, ['aaa', 'bbb'])
      vsplit
      au WinScrolled * close
    ]])

    -- This was using freed memory
    feed('<C-E>')
    assert_alive()
  end)
end)

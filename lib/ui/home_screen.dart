import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_swiper/flutter_swiper.dart';
import 'package:flutter_wanandroid/common/common.dart';
import 'package:flutter_wanandroid/common/user.dart';
import 'package:flutter_wanandroid/data/api/apis_service.dart';
import 'package:flutter_wanandroid/data/model/article_model.dart';
import 'package:flutter_wanandroid/data/model/banner_model.dart';
import 'package:flutter_wanandroid/data/model/base_model.dart';
import 'package:flutter_wanandroid/ui/base_widget.dart';
import 'package:flutter_wanandroid/utils/route_util.dart';
import 'package:flutter_wanandroid/utils/toast_util.dart';
import 'package:flutter_wanandroid/widgets/progress_view.dart';
import 'package:flutter_wanandroid/widgets/refresh_helper.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';

/// 首页
class HomeScreen extends BaseWidget {
  @override
  BaseWidgetState<BaseWidget> attachState() {
    return HomeScreenState();
  }
}

class HomeScreenState extends BaseWidgetState<HomeScreen> {
  /// 首页轮播图数据
  List<BannerBean> _bannerList = new List();

  /// 首页文章列表数据
  List<ArticleBean> _articles = new List();

  /// listview 控制器
  ScrollController _scrollController = new ScrollController();

  /// 是否显示悬浮按钮
  bool _isShowFAB = false;

  /// 页码，从0开始
  int _page = 0;

  RefreshController _refreshController =
      new RefreshController(initialRefresh: false);

  @override
  void initState() {
    super.initState();
    setAppBarVisible(false);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    showLoading().then((value) {
      getBannerList();
      getTopArticleList();
    });

    _scrollController.addListener(() {
      /// 滑动到底部，加载更多
      if (_scrollController.position.pixels ==
          _scrollController.position.maxScrollExtent) {
        // getMoreArticleList();
      }
      if (_scrollController.offset < 200 && _isShowFAB) {
        setState(() {
          _isShowFAB = false;
        });
      } else if (_scrollController.offset >= 200 && !_isShowFAB) {
        setState(() {
          _isShowFAB = true;
        });
      }
    });
  }

  /// 获取首页轮播图数据
  Future getBannerList() async {
    apiService.getBannerList((BannerModel bannerModel) {
      if (bannerModel.data.length > 0) {
        _bannerList = bannerModel.data;
      }
    });
  }

  /// 获取置顶文章数据
  Future getTopArticleList() async {
    apiService.getTopArticleList((TopArticleModel topArticleModel) {
      if (topArticleModel.errorCode == Constants.STATUS_SUCCESS) {
        topArticleModel.data.forEach((v) {
          v.top = 1;
        });
        _articles.clear();
        _articles.addAll(topArticleModel.data);
      }
      getArticleList();
    }, (DioError error) {});
  }

  /// 获取文章列表数据
  Future getArticleList() async {
    _page = 0;
    apiService.getArticleList((ArticleModel model) {
      if (model.errorCode == Constants.STATUS_SUCCESS) {
        if (model.data.datas.length > 0) {
          showContent().then((value) {
            _refreshController.refreshCompleted(resetFooterState: true);
            setState(() {
              _articles.addAll(model.data.datas);
            });
          });
        } else {
          showEmpty();
        }
      } else {
        showError();
        T.show(msg: model.errorMsg);
      }
    }, (DioError error) {
      showError();
    }, _page);
  }

  /// 获取更多文章列表数据
  Future getMoreArticleList() async {
    _page++;
    apiService.getArticleList((ArticleModel model) {
      if (model.errorCode == Constants.STATUS_SUCCESS) {
        if (model.data.datas.length > 0) {
          _refreshController.loadComplete();
          setState(() {
            _articles.addAll(model.data.datas);
          });
        } else {
          _refreshController.loadNoData();
        }
      } else {
        _refreshController.loadFailed();
        T.show(msg: model.errorMsg);
      }
    }, (DioError error) {
      _refreshController.loadFailed();
    }, _page);
  }

  @override
  AppBar attachAppBar() {
    return AppBar(title: Text(""));
  }

  @override
  Widget attachContentWidget(BuildContext context) {
    return Scaffold(
      body: SmartRefresher(
        enablePullDown: true,
        enablePullUp: true,
        header: MaterialClassicHeader(),
        footer: RefreshFooter(),
        controller: _refreshController,
        onRefresh: getTopArticleList,
        onLoading: getMoreArticleList,
        child: ListView.builder(
          itemBuilder: itemView,
          physics: new AlwaysScrollableScrollPhysics(),
          controller: _scrollController,
          itemCount: _articles.length + 1,
        ),
      ),
      floatingActionButton: !_isShowFAB
          ? null
          : FloatingActionButton(
              heroTag: "home",
              child: Icon(Icons.arrow_upward),
              onPressed: () {
                /// 回到顶部时要执行的动画
                _scrollController.animateTo(0,
                    duration: Duration(milliseconds: 2000), curve: Curves.ease);
              },
            ),
    );
  }

  @override
  void onClickErrorWidget() {
    showLoading().then((value) {
      getTopArticleList();
    });
  }

  /// 构建轮播视图
  Widget buildBannerView(BuildContext context) {
    return Offstage(
      offstage: _bannerList.length == 0,
      child: Swiper(
        itemBuilder: (BuildContext context, int index) {
          if (index >= _bannerList.length ||
              _bannerList[index] == null ||
              _bannerList[index].imagePath == null) {
            return new ProgressView();
          } else {
            return InkWell(
              child: new Container(
                child: CachedNetworkImage(
                  fit: BoxFit.fill,
                  imageUrl: _bannerList[index].imagePath,
                  placeholder: (context, url) => new ProgressView(),
                  errorWidget: (context, url, error) => new Icon(Icons.error),
                ),
              ),
              onTap: () {
                RouteUtil.toWebView(
                    context, _bannerList[index].title, _bannerList[index].url);
              },
            );
          }
        },
        itemCount: _bannerList.length,
        autoplay: true,
        pagination: new SwiperPagination(),
        // control: new SwiperControl(),
      ),
    );
  }

  /// ListView 中每一行的视图
  Widget itemView(BuildContext context, int index) {
    if (index == 0) {
      return Container(
        height: 200,
        color: Colors.transparent,
        child: buildBannerView(context),
      );
    }

    if (index < _articles.length - 1) {
      ArticleBean item = _articles[index - 1];

      return InkWell(
        onTap: () {
          RouteUtil.toWebView(context, item.title, item.link);
        },
        child: Column(
          children: <Widget>[
            Container(
              padding: EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Row(
                children: <Widget>[
                  Offstage(
                    offstage: item.top == 0,
                    child: Container(
                      decoration: new BoxDecoration(
                        border: new Border.all(
                            color: Color(0xFFF44336), width: 0.5),
                        borderRadius: new BorderRadius.vertical(
                            top: Radius.elliptical(2, 2),
                            bottom: Radius.elliptical(2, 2)),
                      ),
                      padding: EdgeInsets.fromLTRB(4, 2, 4, 2),
                      margin: EdgeInsets.fromLTRB(0, 0, 4, 0),
                      child: Text(
                        "置顶",
                        style: TextStyle(
                            fontSize: 10, color: const Color(0xFFF44336)),
                        textAlign: TextAlign.left,
                      ),
                    ),
                  ),
                  Offstage(
                    offstage: !item.fresh,
                    child: Container(
                      decoration: new BoxDecoration(
                        border: new Border.all(
                            color: Color(0xFFF44336), width: 0.5),
                        borderRadius: new BorderRadius.vertical(
                            top: Radius.elliptical(2, 2),
                            bottom: Radius.elliptical(2, 2)),
                      ),
                      padding: EdgeInsets.fromLTRB(4, 2, 4, 2),
                      margin: EdgeInsets.fromLTRB(0, 0, 4, 0),
                      child: Text(
                        "新",
                        style: TextStyle(
                            fontSize: 10, color: const Color(0xFFF44336)),
                        textAlign: TextAlign.left,
                      ),
                    ),
                  ),
                  Offstage(
                    offstage: item.tags.length == 0,
                    child: Container(
                      decoration: new BoxDecoration(
                        border: new Border.all(color: Colors.cyan, width: 0.5),
                        borderRadius: new BorderRadius.vertical(
                            top: Radius.elliptical(2, 2),
                            bottom: Radius.elliptical(2, 2)),
                      ),
                      padding: EdgeInsets.fromLTRB(4, 2, 4, 2),
                      margin: EdgeInsets.fromLTRB(0, 0, 4, 0),
                      child: Text(
                        item.tags.length > 0 ? item.tags[0].name : "",
                        style: TextStyle(fontSize: 10, color: Colors.cyan),
                        textAlign: TextAlign.left,
                      ),
                    ),
                  ),
                  Text(
                    item.author,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    textAlign: TextAlign.left,
                  ),
                  Expanded(
                    child: Text(
                      item.niceDate,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              child: Row(
                children: <Widget>[
                  Offstage(
                    offstage: item.envelopePic == "",
                    child: Container(
                      width: 100,
                      height: 80,
                      padding: EdgeInsets.fromLTRB(16, 8, 0, 8),
                      child: CachedNetworkImage(
                        fit: BoxFit.cover,
                        imageUrl: item.envelopePic,
                        placeholder: (context, url) => new ProgressView(),
                        errorWidget: (context, url, error) =>
                            new Icon(Icons.error),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: <Widget>[
                        Container(
                          alignment: Alignment.topLeft,
                          padding: EdgeInsets.fromLTRB(16, 0, 16, 0),
                          child: Text(
                            item.title,
                            maxLines: 2,
                            style: TextStyle(fontSize: 16),
                            textAlign: TextAlign.left,
                          ),
                        ),
                        Container(
                          alignment: Alignment.topLeft,
                          padding: EdgeInsets.fromLTRB(16, 10, 16, 10),
                          child: Row(
                            children: <Widget>[
                              Expanded(
                                child: Text(
                                  item.superChapterName +
                                      " / " +
                                      item.chapterName,
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.grey[600]),
                                  textAlign: TextAlign.left,
                                ),
                              ),
                              InkWell(
                                child: Container(
                                  child: item.collect
                                      ? Image(
                                          image: AssetImage(
                                              'assets/images/ic_like.png'),
                                          width: 24,
                                          height: 24,
                                        )
                                      : Image(
                                          color: Colors.grey[600],
                                          image: AssetImage(
                                              'assets/images/ic_like_not.png'),
                                          width: 24,
                                          height: 24,
                                        ),
                                ),
                                onTap: () {
                                  addOrCancelCollect(item);
                                },
                              )
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1)
          ],
        ),
      );
    }
    return null;
  }

  /// 添加收藏或者取消收藏
  void addOrCancelCollect(item) {
    List<String> cookies = User.singleton.cookie;
    if (cookies == null || cookies.length == 0) {
      T.show(msg: '请先登录~');
    } else {
      if (item.collect) {
        apiService.cancelCollection((BaseModel model) {
          if (model.errorCode == Constants.STATUS_SUCCESS) {
            T.show(msg: '已取消收藏~');
            setState(() {
              item.collect = false;
            });
          } else {
            T.show(msg: '取消收藏失败~');
          }
        }, (DioError error) {
          print(error.response);
        }, item.id);
      } else {
        apiService.addCollection((BaseModel model) {
          if (model.errorCode == Constants.STATUS_SUCCESS) {
            T.show(msg: '收藏成功~');
            setState(() {
              item.collect = true;
            });
          } else {
            T.show(msg: '收藏失败~');
          }
        }, (DioError error) {
          print(error.response);
        }, item.id);
      }
    }
  }

  @override
  void dispose() {
    _refreshController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
